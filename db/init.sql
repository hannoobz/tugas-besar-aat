-- Initialize database for Laporan system
CREATE TABLE IF NOT EXISTS laporan (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create index on status for faster queries
CREATE INDEX IF NOT EXISTS idx_laporan_status ON laporan(status);

-- Insert sample data for testing
INSERT INTO laporan (title, description, status) VALUES
    ('Sample Report 1', 'This is a test report', 'pending'),
    ('Sample Report 2', 'Another test report', 'in_progress'),
    ('Sample Report 3', 'Completed test report', 'completed');
