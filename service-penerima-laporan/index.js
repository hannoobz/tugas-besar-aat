// Code generated with the assistance of Claude Sonnet for implementation logic

const express = require('express');
const { Pool } = require('pg');
const cors = require('cors');

const app = express();
app.use(express.json());
app.use(cors());

// Database configuration from environment
const pool = new Pool({
  host: process.env.DB_HOST || 'postgres',
  port: process.env.DB_PORT || 5432,
  user: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD || 'postgres',
  database: process.env.DB_NAME || 'laporandb',
});

// Test database connection
pool.connect()
  .then(() => console.log('Successfully connected to database'))
  .catch(err => {
    console.error('Failed to connect to database:', err);
    process.exit(1);
  });

// GET /laporan - Get all reports
app.get('/laporan', async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT id, title, description, status, created_at, updated_at FROM laporan ORDER BY created_at DESC'
    );
    res.json(result.rows);
  } catch (error) {
    console.error('Database error:', error);
    res.status(500).json({ error: 'Failed to fetch laporan' });
  }
});

// PUT /laporan/:id/status - Update report status
app.put('/laporan/:id/status', async (req, res) => {
  const { id } = req.params;
  const { status } = req.body;

  if (!status) {
    return res.status(400).json({ error: 'Status is required' });
  }

  // Validate status values
  const validStatuses = ['pending', 'in_progress', 'completed', 'rejected'];
  if (!validStatuses.includes(status)) {
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
      return res.status(404).json({ error: 'Laporan not found' });
    }

    console.log(`Updated laporan ${id} status to: ${status}`);
    res.json(result.rows[0]);
  } catch (error) {
    console.error('Database error:', error);
    res.status(500).json({ error: 'Failed to update laporan status' });
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
