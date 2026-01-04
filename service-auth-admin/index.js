// Code generated with the assistance of Claude Sonnet for implementation logic

const express = require('express');
const { Pool } = require('pg');
const cors = require('cors');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');

const app = express();

// Security Headers
app.use((req, res, next) => {
  res.setHeader('Content-Security-Policy', "default-src 'self'; script-src 'self'; object-src 'none'");
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'DENY');
  next();
});

app.use(express.json());
app.use(cors());

// Database configuration
const pool = new Pool({
  host: process.env.DB_HOST || 'postgres-admin',
  port: process.env.DB_PORT || 5432,
  user: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD || 'postgres',
  database: process.env.DB_NAME || 'admindb',
});

// JWT Configuration
const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key';
const JWT_REFRESH_SECRET = process.env.JWT_REFRESH_SECRET || 'your-refresh-secret';
const JWT_ACCESS_EXPIRY = process.env.JWT_ACCESS_EXPIRY || '15m';
const JWT_REFRESH_EXPIRY = process.env.JWT_REFRESH_EXPIRY || '7d';

// POST /auth/register - Register new admin
app.post('/auth/register', async (req, res) => {
  const { nip, nama, email, password, divisi } = req.body;
  console.log(`[REGISTER] Attempt to register admin: ${nip}`);

  if (!nip || !nama || !email || !password || !divisi) {
    return res.status(400).json({ error: 'NIP, nama, email, password, and divisi are required' });
  }

  const validDivisi = ['kebersihan', 'kesehatan', 'fasilitas umum', 'kriminalitas'];
  if (!validDivisi.includes(divisi)) {
    return res.status(400).json({ error: 'Invalid divisi. Must be one of: kebersihan, kesehatan, fasilitas umum, kriminalitas' });
  }

  try {
    const existingUser = await pool.query(
      'SELECT nip FROM users WHERE nip = $1 OR email = $2',
      [nip, email]
    );

    if (existingUser.rows.length > 0) {
      return res.status(409).json({ error: 'NIP or email already exists' });
    }

    const passwordHash = await bcrypt.hash(password, 10);

    const result = await pool.query(
      'INSERT INTO users (nip, nama, email, password_hash, divisi) VALUES ($1, $2, $3, $4, $5) RETURNING nip, nama, email, divisi, created_at',
      [nip, nama, email, passwordHash, divisi]
    );

    console.log(`[REGISTER SUCCESS] New admin registered: ${nip}`);
    res.status(201).json({
      message: 'Admin registered successfully',
      user: { ...result.rows[0], role: 'admin' }
    });
  } catch (error) {
    console.error('[REGISTER ERROR] Database error:', error);
    res.status(500).json({ error: 'Failed to register admin' });
  }
});

// POST /auth/login - Login admin
app.post('/auth/login', async (req, res) => {
  const { nip, password } = req.body;
  console.log(`[LOGIN] Admin login attempt: ${nip}`);

  if (!nip || !password) {
    return res.status(400).json({ error: 'NIP and password are required' });
  }

  try {
    const result = await pool.query(
      'SELECT nip, nama, email, password_hash, divisi FROM users WHERE nip = $1',
      [nip]
    );

    if (result.rows.length === 0) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const user = result.rows[0];
    const isPasswordValid = await bcrypt.compare(password, user.password_hash);
    
    if (!isPasswordValid) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const accessToken = jwt.sign(
      { userNip: user.nip, nama: user.nama, divisi: user.divisi, role: 'admin' },
      JWT_SECRET,
      { expiresIn: JWT_ACCESS_EXPIRY }
    );

    const refreshToken = jwt.sign(
      { userNip: user.nip },
      JWT_REFRESH_SECRET,
      { expiresIn: JWT_REFRESH_EXPIRY }
    );

    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + 7);

    await pool.query(
      'INSERT INTO refresh_tokens (user_nip, token, expires_at) VALUES ($1, $2, $3)',
      [user.nip, refreshToken, expiresAt]
    );

    console.log(`[LOGIN SUCCESS] Admin logged in: ${nip}`);
    res.json({
      message: 'Login successful',
      accessToken,
      refreshToken,
      user: {
        nip: user.nip,
        nama: user.nama,
        email: user.email,
        divisi: user.divisi,
        role: 'admin'
      }
    });
  } catch (error) {
    console.error('[LOGIN ERROR]:', error);
    res.status(500).json({ error: 'Failed to login' });
  }
});

// GET /auth/verify
app.get('/auth/verify', async (req, res) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'No token provided' });
    }

    const token = authHeader.substring(7);
    const decoded = jwt.verify(token, JWT_SECRET);

    const result = await pool.query(
      'SELECT nip, nama, email, divisi FROM users WHERE nip = $1',
      [decoded.userNip]
    );

    if (result.rows.length === 0) {
      return res.status(401).json({ error: 'User not found' });
    }

    res.json({
      valid: true,
      user: { ...result.rows[0], role: 'admin' }
    });
  } catch (error) {
    res.status(401).json({ error: 'Invalid token' });
  }
});

// POST /auth/refresh
app.post('/auth/refresh', async (req, res) => {
  const { refreshToken } = req.body;

  if (!refreshToken) {
    return res.status(400).json({ error: 'Refresh token is required' });
  }

  try {
    const decoded = jwt.verify(refreshToken, JWT_REFRESH_SECRET);

    const tokenResult = await pool.query(
      'SELECT id, user_nip, expires_at, revoked FROM refresh_tokens WHERE token = $1',
      [refreshToken]
    );

    if (tokenResult.rows.length === 0 || tokenResult.rows[0].revoked || 
        new Date(tokenResult.rows[0].expires_at) < new Date()) {
      return res.status(401).json({ error: 'Invalid refresh token' });
    }

    const userResult = await pool.query(
      'SELECT nip, nama, email, divisi FROM users WHERE nip = $1',
      [decoded.userNip]
    );

    if (userResult.rows.length === 0) {
      return res.status(401).json({ error: 'User not found' });
    }

    const user = userResult.rows[0];
    const accessToken = jwt.sign(
      { userNip: user.nip, nama: user.nama, divisi: user.divisi, role: 'admin' },
      JWT_SECRET,
      { expiresIn: JWT_ACCESS_EXPIRY }
    );

    res.json({
      accessToken,
      user: { ...user, role: 'admin' }
    });
  } catch (error) {
    res.status(401).json({ error: 'Invalid refresh token' });
  }
});

// POST /auth/logout
app.post('/auth/logout', async (req, res) => {
  const { refreshToken } = req.body;

  if (!refreshToken) {
    return res.status(400).json({ error: 'Refresh token is required' });
  }

  try {
    await pool.query(
      'UPDATE refresh_tokens SET revoked = TRUE WHERE token = $1',
      [refreshToken]
    );

    res.json({ message: 'Logout successful' });
  } catch (error) {
    res.status(500).json({ error: 'Failed to logout' });
  }
});

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'healthy' });
});

const PORT = process.env.PORT || 3001;
app.listen(PORT, () => {
  console.log(`Service Auth Admin starting on port ${PORT}`);
});
