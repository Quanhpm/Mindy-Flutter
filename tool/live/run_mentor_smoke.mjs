// Dùng fixture Nest đã có của backend sibling; không sửa source backend, không
// dùng .env. Chỉ cho phép PostgreSQL kiểm thử riêng của MindyFlutter tại local.
import { fork, spawn } from 'node:child_process';
import { generateKeyPairSync, randomUUID } from 'node:crypto';
import { mkdtemp, rm, writeFile } from 'node:fs/promises';
import { createRequire } from 'node:module';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const flutterRoot = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const backendRoot = resolve(flutterRoot, '../Mindy-BE');
const require = createRequire(join(backendRoot, 'package.json'));
const { DataSource } = require('typeorm');
const dbUrl = new URL(process.env.MINDY_UAT_DATABASE_URL ?? '');
if (dbUrl.hostname !== '127.0.0.1' || dbUrl.port !== '25433' ||
    dbUrl.username !== 'mindy_flutter_test' || dbUrl.pathname !== '/mindy_flutter_test') {
  throw new Error('Requires the isolated MindyFlutter test PostgreSQL on 127.0.0.1:25433');
}
const password = process.env.MINDY_UAT_PASSWORD;
if (!password) throw new Error('MINDY_UAT_PASSWORD must match the backend HTTP fixture password');
if (!process.version.startsWith('v22.')) throw new Error('Backend requires Node 22');
const childDb = new URL(dbUrl);
childDb.pathname = '/mindy_flutter_smoke_http_test';
const keys = generateKeyPairSync('rsa', { modulusLength: 2048 });
const directory = await mkdtemp(join(tmpdir(), 'mindy-flutter-smoke-'));
const files = process.env.MINDY_UAT_FILES === '1';
const Bucket = `mindy-flutter-${randomUUID()}-test`;
let storage;
let bucketCreated = false;
let s3;
let server;
let db;
try {
  if (files) {
    if (!process.env.MINDY_UAT_MINIO_USER || !process.env.MINDY_UAT_MINIO_PASSWORD) {
      throw new Error('Files smoke requires the isolated MinIO test credentials');
    }
    s3 = require('@aws-sdk/client-s3');
    storage = new s3.S3Client({ endpoint: 'http://127.0.0.1:19000', region: 'us-east-1', forcePathStyle: true,
      maxAttempts: 1, credentials: { accessKeyId: process.env.MINDY_UAT_MINIO_USER, secretAccessKey: process.env.MINDY_UAT_MINIO_PASSWORD } });
    await storage.send(new s3.CreateBucketCommand({ Bucket }));
    bucketCreated = true;
    await storage.send(new s3.PutBucketVersioningCommand({ Bucket, VersioningConfiguration: { Status: 'Enabled' } }));
    const { PDFDocument } = require('pdf-lib');
    const pdf = await PDFDocument.create();
    pdf.addPage([300, 200]).drawText('Mindy synthetic upload smoke', { x: 20, y: 100, size: 12 });
    await writeFile(join(directory, 'smoke.pdf'), await pdf.save(), { mode: 0o600 });
  }
  server = fork(join(backendRoot, 'test/http/payment-server.mjs'), [], {
    cwd: backendRoot, execArgv: [], silent: true,
    env: {
      ...process.env, NODE_ENV: 'test', TEST_DATABASE_URL: dbUrl.toString(), DATABASE_URL: childDb.toString(),
      DATABASE_LOGGING: 'false', COOKIE_SECURE: 'false', CORS_ORIGINS: 'http://localhost:3001',
      GOOGLE_AUTH_ENABLED: 'false', MAIL_ENABLED: 'false', ORDER_EXPIRY_JOB_ENABLED: 'false',
      PAYMENT_MAIL_JOB_ENABLED: 'false', PAYOS_ENABLED: 'false', MINIO_ENABLED: 'false', CHAT_ENABLED: 'false',
      ...(files ? {
        MINIO_ENABLED: 'true', MINIO_ENDPOINT: '127.0.0.1', MINIO_PORT: '19000', MINIO_USE_SSL: 'false',
        MINIO_PUBLIC_URL: 'http://127.0.0.1:19000', MINIO_BUCKET: Bucket,
        MINIO_ACCESS_KEY: process.env.MINDY_UAT_MINIO_USER, MINIO_SECRET_KEY: process.env.MINDY_UAT_MINIO_PASSWORD,
        FILE_JOB_ENABLED: 'true', FILE_JOB_POLL_SECONDS: '1',
      } : {}),
      JWT_PRIVATE_KEY_BASE64: Buffer.from(keys.privateKey.export({ type: 'pkcs8', format: 'pem' })).toString('base64'),
      JWT_PUBLIC_KEY_BASE64: Buffer.from(keys.publicKey.export({ type: 'spki', format: 'pem' })).toString('base64'),
    },
  });
  // Không ghi body, cookie hay credential vào output.
  const ready = await new Promise((resolveReady, reject) => {
    const timeout = setTimeout(() => reject(new Error('Fixture startup timed out')), 30000);
    server.once('message', (value) => { clearTimeout(timeout); resolveReady(value); });
    server.once('exit', (code) => { clearTimeout(timeout); reject(new Error(`Fixture exited ${code}`)); });
    server.once('error', (error) => { clearTimeout(timeout); reject(error); });
  });
  const base = `${ready.url}/api/v1`;
  async function request(path, cookie, body) {
    const response = await fetch(`${base}${path}`, {
      method: 'POST', headers: { 'content-type': 'application/json', Origin: 'http://localhost:3001', ...(cookie ? { cookie } : {}) },
      body: JSON.stringify(body),
    });
    if (!response.ok) throw new Error(`Fixture request ${path} returned ${response.status}`);
    return response;
  }
  async function login(email) {
    const response = await request('/auth/login', null, { email, password });
    return response.headers.getSetCookie().map((cookie) => cookie.split(';')[0]).join('; ');
  }
  const student = await login('student@http.test');
  const manager = await login('manager@http.test');
  await request('/me/cart/items', student, { classId: ready.classId });
  const checkout = await (await request('/me/cart/checkout', student, { paymentType: 'CASH' })).json();
  const order = checkout.orders[0];
  await request(`/manager/cash-orders/${order.id}/confirm`, manager, { receivedAmount: order.totalAmount });
  db = new DataSource({ type: 'postgres', url: childDb.toString() });
  await db.initialize();
  // Cùng cách setup buổi hôm nay của test/http/phase42-attendance.spec.ts.
  await db.query(`UPDATE class_sessions SET
    starts_at=date_trunc('day',now() AT TIME ZONE 'Asia/Ho_Chi_Minh') AT TIME ZONE 'Asia/Ho_Chi_Minh',
    ends_at=(date_trunc('day',now() AT TIME ZONE 'Asia/Ho_Chi_Minh')+interval '1 day'-interval '1 millisecond') AT TIME ZONE 'Asia/Ho_Chi_Minh'
    WHERE class_id=$1`, [ready.classId]);
  const sessions = await db.query('SELECT id FROM class_sessions WHERE class_id=$1', [ready.classId]);
  if (sessions.length !== 1) throw new Error('Expected one isolated fixture session');
  const config = join(directory, 'env.json');
  await writeFile(config, JSON.stringify({ API_URL: base, APP_ORIGIN: 'http://localhost:3001', APP_ENV: 'development', DEBUG_MODE: 'false' }), { mode: 0o600 });
  const code = await new Promise((resolveExit, reject) => {
    const flutter = spawn(process.env.FLUTTER_BIN ?? 'flutter', [
      'test', 'test/live/mentor_smoke_test.dart', '--no-pub', `--dart-define-from-file=${config}`, '--reporter', 'expanded',
    ], { cwd: flutterRoot, stdio: 'inherit', env: { ...process.env, MINDY_UAT_LIVE: '1', MINDY_UAT_SESSION_ID: sessions[0].id,
      ...(files ? { MINDY_UAT_FILE_PATH: join(directory, 'smoke.pdf') } : {}) } });
    flutter.once('error', reject);
    flutter.once('exit', resolveExit);
  });
  process.exitCode = code ?? 1;
} finally {
  if (db?.isInitialized) await db.destroy();
  if (server && server.exitCode === null) {
    await new Promise((resolveClosed) => {
      server.once('exit', resolveClosed);
      server.send('close');
      const timer = setTimeout(() => { server.kill(); resolveClosed(); }, 5000);
      timer.unref();
    });
  }
  if (bucketCreated) {
    // Chỉ xóa bucket UUID do chính lần chạy này tạo, không list hay sửa bucket khác.
    for (;;) {
      const versions = await storage.send(new s3.ListObjectVersionsCommand({ Bucket, MaxKeys: 1000 }));
      const objects = [...(versions.Versions ?? []), ...(versions.DeleteMarkers ?? [])].map((v) => ({ Key: v.Key, VersionId: v.VersionId }));
      if (!objects.length) break;
      await storage.send(new s3.DeleteObjectsCommand({ Bucket, Delete: { Objects: objects } }));
    }
    await storage.send(new s3.DeleteBucketCommand({ Bucket }));
  }
  storage?.destroy();
  await rm(directory, { recursive: true, force: true });
}
