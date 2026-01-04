// Code generated with the assistance of Claude Sonnet for implementation logic

const express = require('express');
const { Pool } = require('pg');
const cors = require('cors');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');

const app = express();

// Security Headers Middleware
app.use((req, res, next) => {
  res.setHeader('Content-Security-Policy', "default-src 'self'; script-src 'self'; object-src 'none'");
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'DENY');
  res.setHeader('X-XSS-Protection', '1; mode=block');
  res.setHeader('Referrer-Policy', 'strict-origin-when-cross-origin');
  next();
});

app.use(express.json());
app.use(cors());

// Database configuration for laporan (reports)
const pool = new Pool({
  host: process.env.DB_HOST || 'postgres',
  port: process.env.DB_PORT || 5432,
  user: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD || 'postgres',
  database: process.env.DB_NAME || 'laporandb',
});

// Database configuration for authentication
const authPool = new Pool({
  host: process.env.AUTH_DB_HOST || 'postgres-auth',
  port: process.env.AUTH_DB_PORT || 5432,
  user: process.env.AUTH_DB_USER || 'postgres',
  password: process.env.AUTH_DB_PASSWORD || 'postgres',
  database: process.env.AUTH_DB_NAME || 'authdb',
});

// JWT Configuration
const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key';
const JWT_REFRESH_SECRET = process.env.JWT_REFRESH_SECRET || 'your-refresh-secret';
const JWT_ACCESS_EXPIRY = process.env.JWT_ACCESS_EXPIRY || '15m';
const JWT_REFRESH_EXPIRY = process.env.JWT_REFRESH_EXPIRY || '7d';

// Password requirements
const PASSWORD_MIN_LENGTH = 8;

// Middleware to validate password requirements
const validatePassword = (password) => {
  if (!password || password.length < PASSWORD_MIN_LENGTH) {
    return `Password must be at least ${PASSWORD_MIN_LENGTH} characters long`;
  }
  
  const hasLower = /[a-z]/.test(password);
  const hasUpper = /[A-Z]/.test(password);
  const hasDigit = /\d/.test(password);
  const hasSpecial = /[@$!%*?&]/.test(password);
  
  if (!hasLower) {
    return 'Password must contain at least one lowercase letter';
  }
  if (!hasUpper) {
    return 'Password must contain at least one uppercase letter';
  }
  if (!hasDigit) {
    return 'Password must contain at least one number';
  }
  if (!hasSpecial) {
    return 'Password must contain at least one special character (@$!%*?&)';
  }
  
  return null;
};

// Middleware to verify JWT token (admin only)
const verifyAdminToken = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      console.log('[AUTH ERROR] No token provided in request');
      return res.status(401).json({ error: 'No token provided' });
    }

    const token = authHeader.substring(7);
    console.log('[AUTH] Verifying admin token...');
    const decoded = jwt.verify(token, JWT_SECRET);

    // Check if user is admin (role is hardcoded in token)
    if (decoded.role !== 'admin') {
      console.log(`[AUTH ERROR] Access denied - not admin role (role: ${decoded.role})`);
      return res.status(403).json({ error: 'Access denied. Admin only.' });
    }

    // Verify user still exists
    const result = await authPool.query(
      'SELECT id, username, email FROM users WHERE id = $1 AND username IS NOT NULL',
      [decoded.userId]
    );

    if (result.rows.length === 0) {
      console.log(`[AUTH ERROR] Admin not found in database: userId=${decoded.userId}`);
      return res.status(401).json({ error: 'User not found' });
    }

    req.user = { ...result.rows[0], role: 'admin' };
    console.log(`[AUTH SUCCESS] Admin verified: ${req.user.username}`);
    next();
  } catch (error) {
    if (error.name === 'TokenExpiredError') {
      console.log('[AUTH ERROR] Token expired:', error.message);
      return res.status(401).json({ error: 'Token expired' });
    }
    if (error.name === 'JsonWebTokenError') {
      console.log('[AUTH ERROR] Invalid token:', error.message);
      return res.status(401).json({ error: 'Invalid token' });
    }
    console.error('[AUTH ERROR] Token verification failed:', error);
    res.status(500).json({ error: 'Authentication failed' });
  }
};

// Middleware to verify JWT token (warga only)
const verifyWargaToken = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      console.log('[AUTH ERROR] No token provided in request');
      return res.status(401).json({ error: 'No token provided' });
    }

    const token = authHeader.substring(7);
    console.log('[AUTH] Verifying warga token...');
    const decoded = jwt.verify(token, JWT_SECRET);

    // Check if user is warga (role is hardcoded in token)
    if (decoded.role !== 'warga') {
      console.log(`[AUTH ERROR] Access denied - not warga role (role: ${decoded.role})`);
      return res.status(403).json({ error: 'Access denied. Warga only.' });
    }

    // Verify user still exists
    const result = await authPool.query(
      'SELECT id, nik, nama, email FROM users WHERE id = $1',
      [decoded.userId]
    );

    if (result.rows.length === 0) {
      console.log(`[AUTH ERROR] User not found in database: userId=${decoded.userId}`);
      return res.status(401).json({ error: 'User not found' });
    }

    req.user = { ...result.rows[0], role: 'warga' };
    console.log(`[AUTH SUCCESS] Warga verified: ${req.user.nik} (${req.user.nama})`);
    next();
  } catch (error) {
    if (error.name === 'TokenExpiredError') {
      console.log('[AUTH ERROR] Token expired:', error.message);
      return res.status(401).json({ error: 'Token expired' });
    }
    if (error.name === 'JsonWebTokenError') {
      console.log('[AUTH ERROR] Invalid token:', error.message);
      return res.status(401).json({ error: 'Invalid token' });
    }
    console.error('[AUTH ERROR] Token verification failed:', error);
    res.status(500).json({ error: 'Authentication failed' });
  }
};

// POST /auth/register - Register new admin
app.post('/auth/register', async (req, res) => {
  const { username, email, password } = req.body;
  console.log(`[REGISTER] Attempt to register admin: ${username}`);

  // Validate input
  if (!username || !email || !password) {
    console.log('[REGISTER ERROR] Missing required fields');
    return res.status(400).json({ error: 'Username, email, and password are required' });
  }

  // Validate password requirements
  const passwordError = validatePassword(password);
  if (passwordError) {
    console.log(`[REGISTER ERROR] Password validation failed: ${passwordError}`);
    return res.status(400).json({ error: passwordError });
  }

  try {
    // Check if username already exists
    const existingUser = await authPool.query(
      'SELECT id FROM users WHERE username = $1 OR email = $2',
      [username, email]
    );

    if (existingUser.rows.length > 0) {
      console.log(`[REGISTER ERROR] Username or email already exists: ${username} / ${email}`);
      return res.status(409).json({ error: 'Username or email already exists' });
    }

    // Hash password
    const saltRounds = 10;
    const passwordHash = await bcrypt.hash(password, saltRounds);

    // Create new admin user (role is 'admin' but not stored in DB)
    const result = await authPool.query(
      'INSERT INTO users (username, email, password_hash) VALUES ($1, $2, $3) RETURNING id, username, email, created_at',
      [username, email, passwordHash]
    );

    console.log(`[REGISTER SUCCESS] New admin registered: ${username} (id: ${result.rows[0].id})`);
    res.status(201).json({
      message: 'Admin registered successfully',
      user: { ...result.rows[0], role: 'admin' }
    });
  } catch (error) {
    console.error('[REGISTER ERROR] Database error:', error);
    res.status(500).json({ error: 'Failed to register admin' });
  }
});

// POST /auth/register-user - Register new warga
app.post('/auth/register-user', async (req, res) => {
  const { nik, nama, email, password } = req.body;
  console.log(`[REGISTER USER] Attempt to register warga: ${nik}`);

  // Validate input
  if (!nik || !nama || !email || !password) {
    console.log('[REGISTER USER ERROR] Missing required fields');
    return res.status(400).json({ error: 'NIK, nama, email, and password are required' });
  }

  // Validate NIK (16 digits)
  if (!/^\d{16}$/.test(nik)) {
    console.log('[REGISTER USER ERROR] Invalid NIK format');
    return res.status(400).json({ error: 'NIK must be exactly 16 digits' });
  }

  // Validate password requirements
  const passwordError = validatePassword(password);
  if (passwordError) {
    console.log(`[REGISTER USER ERROR] Password validation failed: ${passwordError}`);
    return res.status(400).json({ error: passwordError });
  }

  try {
    // Check if NIK or email already exists
    const existingUser = await authPool.query(
      'SELECT id FROM users WHERE nik = $1 OR email = $2',
      [nik, email]
    );

    if (existingUser.rows.length > 0) {
      console.log(`[REGISTER USER ERROR] NIK or email already exists: ${nik} / ${email}`);
      return res.status(409).json({ error: 'NIK or email already exists' });
    }

    // Hash password
    const saltRounds = 10;
    const passwordHash = await bcrypt.hash(password, saltRounds);

    // Create new warga (role is 'warga' but not stored in DB)
    const result = await authPool.query(
      'INSERT INTO users (nik, nama, email, password_hash) VALUES ($1, $2, $3, $4) RETURNING id, nik, nama, email, created_at',
      [nik, nama, email, passwordHash]
    );

    console.log(`[REGISTER USER SUCCESS] New warga registered: ${nik} (id: ${result.rows[0].id})`);
    res.status(201).json({
      message: 'User registered successfully',
      user: { ...result.rows[0], role: 'warga' }
    });
  } catch (error) {
    console.error('[REGISTER USER ERROR] Database error:', error);
    res.status(500).json({ error: 'Failed to register user' });
  }
});

// POST /auth/login - Login admin
app.post('/auth/login', async (req, res) => {
  const { username, password } = req.body;
  console.log(`[LOGIN] Admin login attempt: ${username}`);

  if (!username || !password) {
    console.log('[LOGIN ERROR] Missing credentials');
    return res.status(400).json({ error: 'Username and password are required' });
  }

  try {
    // Find user by username (only admins have username)
    const result = await authPool.query(
      'SELECT id, username, email, password_hash FROM users WHERE username = $1',
      [username]
    );

    if (result.rows.length === 0) {
      console.log(`[LOGIN ERROR] Admin not found: ${username}`);
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const user = result.rows[0];

    // Verify password
    const isPasswordValid = await bcrypt.compare(password, user.password_hash);
    if (!isPasswordValid) {
      console.log(`[LOGIN ERROR] Invalid password for admin: ${username}`);
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    // Generate access token with hardcoded role 'admin'
    const accessToken = jwt.sign(
      { userId: user.id, username: user.username, role: 'admin' },
      JWT_SECRET,
      { expiresIn: JWT_ACCESS_EXPIRY }
    );

    // Generate refresh token
    const refreshToken = jwt.sign(
      { userId: user.id },
      JWT_REFRESH_SECRET,
      { expiresIn: JWT_REFRESH_EXPIRY }
    );

    // Calculate expiry date for refresh token
    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + 7); // 7 days

    // Store refresh token in database
    await authPool.query(
      'INSERT INTO refresh_tokens (user_id, token, expires_at) VALUES ($1, $2, $3)',
      [user.id, refreshToken, expiresAt]
    );

    console.log(`[LOGIN SUCCESS] Admin logged in: ${username}`);
    res.json({
      message: 'Login successful',
      accessToken,
      refreshToken,
      user: {
        id: user.id,
        username: user.username,
        email: user.email,
        role: 'admin'
      }
    });
  } catch (error) {
    console.error('[LOGIN ERROR] Login failed:', error);
    res.status(500).json({ error: 'Failed to login' });
  }
});

// POST /auth/login-user - Login warga
app.post('/auth/login-user', async (req, res) => {
  const { nik, password } = req.body;
  console.log(`[LOGIN USER] Warga login attempt: ${nik}`);

  if (!nik || !password) {
    console.log('[LOGIN USER ERROR] Missing credentials');
    return res.status(400).json({ error: 'NIK and password are required' });
  }

  try {
    // Find user by NIK
    const result = await authPool.query(
      'SELECT id, nik, nama, email, password_hash FROM users WHERE nik = $1',
      [nik]
    );

    if (result.rows.length === 0) {
      console.log(`[LOGIN USER ERROR] User not found: ${nik}`);
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const user = result.rows[0];

    // Verify password
    const isPasswordValid = await bcrypt.compare(password, user.password_hash);
    if (!isPasswordValid) {
      console.log(`[LOGIN USER ERROR] Invalid password for user: ${nik}`);
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    // Generate access token with hardcoded role 'warga'
    const accessToken = jwt.sign(
      { userId: user.id, nik: user.nik, nama: user.nama, role: 'warga' },
      JWT_SECRET,
      { expiresIn: JWT_ACCESS_EXPIRY }
    );

    // Generate refresh token
    const refreshToken = jwt.sign(
      { userId: user.id },
      JWT_REFRESH_SECRET,
      { expiresIn: JWT_REFRESH_EXPIRY }
    );

    // Calculate expiry date for refresh token
    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + 7); // 7 days

    // Store refresh token in database
    await authPool.query(
      'INSERT INTO refresh_tokens (user_id, token, expires_at) VALUES ($1, $2, $3)',
      [user.id, refreshToken, expiresAt]
    );

    console.log(`[LOGIN USER SUCCESS] Warga logged in: ${nik}`);
    res.json({
      message: 'Login successful',
      accessToken,
      refreshToken,
      user: {
        id: user.id,
        nik: user.nik,
        nama: user.nama,
        email: user.email,
        role: 'warga'
      }
    });
  } catch (error) {
    console.error('[LOGIN USER ERROR] Login failed:', error);
    res.status(500).json({ error: 'Failed to login' });
  }
});

// GET /auth/verify - Verify token validity
app.get('/auth/verify', async (req, res) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'No token provided' });
    }

    const token = authHeader.substring(7);
    const decoded = jwt.verify(token, JWT_SECRET);

    // Determine query based on role
    let result;
    if (decoded.role === 'admin') {
      result = await authPool.query(
        'SELECT id, username, email FROM users WHERE id = $1 AND username IS NOT NULL',
        [decoded.userId]
      );
    } else {
      result = await authPool.query(
        'SELECT id, nik, nama, email FROM users WHERE id = $1',
        [decoded.userId]
      );
    }

    if (result.rows.length === 0) {
      return res.status(401).json({ error: 'User not found' });
    }

    const user = { ...result.rows[0], role: decoded.role };

    res.json({
      valid: true,
      user
    });
  } catch (error) {
    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({ error: 'Token expired' });
    }
    if (error.name === 'JsonWebTokenError') {
      return res.status(401).json({ error: 'Invalid token' });
    }
    console.error('Token verification error:', error);
    res.status(500).json({ error: 'Verification failed' });
  }
});

// POST /auth/refresh - Refresh access token
app.post('/auth/refresh', async (req, res) => {
  const { refreshToken } = req.body;
  console.log('[REFRESH] Token refresh attempt');

  if (!refreshToken) {
    console.log('[REFRESH ERROR] No refresh token provided');
    return res.status(400).json({ error: 'Refresh token is required' });
  }

  try {
    // Verify refresh token
    const decoded = jwt.verify(refreshToken, JWT_REFRESH_SECRET);
    console.log(`[REFRESH] Token verified for userId: ${decoded.userId}`);

    // Check if refresh token exists and is not revoked
    const tokenResult = await authPool.query(
      'SELECT id, user_id, expires_at, revoked FROM refresh_tokens WHERE token = $1',
      [refreshToken]
    );

    if (tokenResult.rows.length === 0) {
      console.log('[REFRESH ERROR] Refresh token not found in database');
      return res.status(401).json({ error: 'Invalid refresh token' });
    }

    const tokenData = tokenResult.rows[0];

    if (tokenData.revoked) {
      console.log('[REFRESH ERROR] Refresh token has been revoked');
      return res.status(401).json({ error: 'Refresh token has been revoked' });
    }

    if (new Date(tokenData.expires_at) < new Date()) {
      console.log('[REFRESH ERROR] Refresh token has expired');
      return res.status(401).json({ error: 'Refresh token has expired' });
    }

    // Get user data - check if admin or warga
    const adminResult = await authPool.query(
      'SELECT id, username, email FROM users WHERE id = $1 AND username IS NOT NULL',
      [decoded.userId]
    );

    let user, accessToken;

    if (adminResult.rows.length > 0) {
      // User is admin
      user = { ...adminResult.rows[0], role: 'admin' };
      accessToken = jwt.sign(
        { userId: user.id, username: user.username, role: 'admin' },
        JWT_SECRET,
        { expiresIn: JWT_ACCESS_EXPIRY }
      );
    } else {
      // User is warga
      const wargaResult = await authPool.query(
        'SELECT id, nik, nama, email FROM users WHERE id = $1',
        [decoded.userId]
      );

      if (wargaResult.rows.length === 0) {
        console.log(`[REFRESH ERROR] User not found: userId=${decoded.userId}`);
        return res.status(401).json({ error: 'User not found' });
      }

      user = { ...wargaResult.rows[0], role: 'warga' };
      accessToken = jwt.sign(
        { userId: user.id, nik: user.nik, nama: user.nama, role: 'warga' },
        JWT_SECRET,
        { expiresIn: JWT_ACCESS_EXPIRY }
      );
    }

    console.log(`[REFRESH SUCCESS] Token refreshed for user: ${user.role === 'admin' ? user.username : user.nik}`);
    res.json({
      accessToken,
      user
    });
  } catch (error) {
    if (error.name === 'TokenExpiredError') {
      console.log('[REFRESH ERROR] Refresh token expired:', error.message);
      return res.status(401).json({ error: 'Refresh token expired' });
    }
    if (error.name === 'JsonWebTokenError') {
      console.log('[REFRESH ERROR] Invalid refresh token:', error.message);
      return res.status(401).json({ error: 'Invalid refresh token' });
    }
    console.error('[REFRESH ERROR] Failed to refresh token:', error);
    res.status(500).json({ error: 'Failed to refresh token' });
  }
});

// POST /auth/logout - Logout admin (revoke refresh token)
app.post('/auth/logout', async (req, res) => {
  const { refreshToken } = req.body;
  console.log('[LOGOUT] Logout attempt');

  if (!refreshToken) {
    console.log('[LOGOUT ERROR] No refresh token provided');
    return res.status(400).json({ error: 'Refresh token is required' });
  }

  try {
    // Revoke the refresh token
    const result = await authPool.query(
      'UPDATE refresh_tokens SET revoked = TRUE WHERE token = $1 RETURNING user_id',
      [refreshToken]
    );

    if (result.rows.length === 0) {
      console.log('[LOGOUT ERROR] Refresh token not found');
      return res.status(404).json({ error: 'Refresh token not found' });
    }

    console.log(`[LOGOUT SUCCESS] User logged out: ${result.rows[0].user_id}`);
    res.json({ message: 'Logout successful' });
  } catch (error) {
    console.error('[LOGOUT ERROR] Logout failed:', error);
    res.status(500).json({ error: 'Failed to logout' });
  }
});

// GET /laporan - Get all reports (Protected - Admin only)
app.get('/laporan', verifyAdminToken, async (req, res) => {
  console.log(`[GET LAPORAN] Request by admin: ${req.user.username}`);
  try {
    const result = await pool.query(
      'SELECT id, title, description, status, created_at, updated_at FROM laporan ORDER BY created_at DESC'
    );
    console.log(`[GET LAPORAN SUCCESS] Retrieved ${result.rows.length} reports`);
    res.json(result.rows);
  } catch (error) {
    console.error('[GET LAPORAN ERROR] Database error:', error);
    res.status(500).json({ error: 'Failed to fetch laporan' });
  }
});

// PUT /laporan/:id/status - Update report status (Protected - Admin only)
app.put('/laporan/:id/status', verifyAdminToken, async (req, res) => {
  const { id } = req.params;
  const { status } = req.body;
  console.log(`[UPDATE STATUS] Admin ${req.user.username} updating laporan ${id} to status: ${status}`);

  if (!status) {
    console.log('[UPDATE STATUS ERROR] No status provided');
    return res.status(400).json({ error: 'Status is required' });
  }

  // Validate status values
  const validStatuses = ['pending', 'in_progress', 'completed', 'rejected'];
  if (!validStatuses.includes(status)) {
    console.log(`[UPDATE STATUS ERROR] Invalid status value: ${status}`);
    return res.status(400).json({ 
      error: 'Invalid status. Must be one of: pending, in_progress, completed, rejected' 
    });
  }

  try {
    const result = await pool.query(
      'UPDATE laporan SET status = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2 RETURNING *',
      [status, id]
    );

    if (result.rows.length === 0) {
      console.log(`[UPDATE STATUS ERROR] Laporan not found: id=${id}`);
      return res.status(404).json({ error: 'Laporan not found' });
    }

    console.log(`[UPDATE STATUS SUCCESS] Updated laporan ${id} status to: ${status}`);
    res.json(result.rows[0]);
  } catch (error) {
    console.error('[UPDATE STATUS ERROR] Database error:', error);
    res.status(500).json({ error: 'Failed to update laporan status' });
  }
});

// POST /laporan - Create new report (Protected - Warga only)
app.post('/laporan', verifyWargaToken, async (req, res) => {
  const { title, description } = req.body;
  console.log(`[CREATE LAPORAN] Warga ${req.user.nik} creating new laporan`);

  if (!title || !description) {
    console.log('[CREATE LAPORAN ERROR] Missing title or description');
    return res.status(400).json({ error: 'Title and description are required' });
  }

  try {
    const result = await pool.query(
      'INSERT INTO laporan (title, description, user_id, status) VALUES ($1, $2, $3, $4) RETURNING *',
      [title, description, req.user.id, 'pending']
    );

    console.log(`[CREATE LAPORAN SUCCESS] New laporan created by warga ${req.user.nik}: ${result.rows[0].id}`);
    res.status(201).json(result.rows[0]);
  } catch (error) {
    console.error('[CREATE LAPORAN ERROR] Database error:', error);
    res.status(500).json({ error: 'Failed to create laporan' });
  }
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'healthy' });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Service Penerima Laporan starting on port ${PORT}`);
});
