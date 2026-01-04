// Code generated with the assistance of Claude Sonnet for implementation logic

package main

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/golang-jwt/jwt/v5"
	_ "github.com/lib/pq"
)

type Laporan struct {
	ID          int    `json:"id"`
	Title       string `json:"title"`
	Description string `json:"description"`
	Tipe        string `json:"tipe"`
	Divisi      string `json:"divisi"`
	Status      string `json:"status"`
}

type CreateLaporanRequest struct {
	Title       string `json:"title"`
	Description string `json:"description"`
	Tipe        string `json:"tipe"`
	Divisi      string `json:"divisi"`
	UserNikHash string `json:"userNikHash,omitempty"`
}

type User struct {
	ID           int       `json:"id"`
	NIK          string    `json:"nik,omitempty"`
	Username     string    `json:"username,omitempty"`
	Nama         string    `json:"nama,omitempty"`
	Email        string    `json:"email"`
	PasswordHash string    `json:"-"`
	CreatedAt    time.Time `json:"created_at"`
}

type RegisterRequest struct {
	NIK      string `json:"nik"`
	Nama     string `json:"nama"`
	Email    string `json:"email"`
	Password string `json:"password"`
}

type LoginRequest struct {
	NIK      string `json:"nik"`
	Password string `json:"password"`
}

type RefreshTokenRequest struct {
	RefreshToken string `json:"refreshToken"`
}

type Claims struct {
	UserID   int    `json:"userId"`
	NIK      string `json:"nik,omitempty"`
	Username string `json:"username,omitempty"`
	Nama     string `json:"nama,omitempty"`
	Role     string `json:"role"` // hardcoded as 'warga'
	jwt.RegisteredClaims
}

type RefreshClaims struct {
	UserID int `json:"userId"`
	jwt.RegisteredClaims
}

var db *sql.DB
var authDB *sql.DB

// Pod hostname for load balancing visibility
var podHostname string

// JWT Configuration
var jwtSecret []byte
var jwtRefreshSecret []byte
var jwtAccessExpiry string
var jwtRefreshExpiry string

func main() {
	// Get pod hostname for load balancing visibility
	podHostname, _ = os.Hostname()
	log.Printf("Pod hostname: %s\n", podHostname)

	// Get database connection details from environment
	dbHost := getEnv("DB_HOST", "postgres")
	dbPort := getEnv("DB_PORT", "5432")
	dbUser := getEnv("DB_USER", "postgres")
	dbPassword := getEnv("DB_PASSWORD", "postgres")
	dbName := getEnv("DB_NAME", "laporandb")

	// Get auth database connection details
	authDBHost := getEnv("AUTH_DB_HOST", "postgres-auth")
	authDBPort := getEnv("AUTH_DB_PORT", "5432")
	authDBUser := getEnv("AUTH_DB_USER", "postgres")
	authDBPassword := getEnv("AUTH_DB_PASSWORD", "postgres")
	authDBName := getEnv("AUTH_DB_NAME", "authdb")

	// JWT Configuration
	jwtSecret = []byte(getEnv("JWT_SECRET", "your-secret-key"))
	jwtRefreshSecret = []byte(getEnv("JWT_REFRESH_SECRET", "your-refresh-secret"))
	jwtAccessExpiry = getEnv("JWT_ACCESS_EXPIRY", "15m")
	jwtRefreshExpiry = getEnv("JWT_REFRESH_EXPIRY", "7d")

	// Connect to PostgreSQL (Laporan database)
	connStr := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=disable",
		dbHost, dbPort, dbUser, dbPassword, dbName)

	var err error
	db, err = sql.Open("postgres", connStr)
	if err != nil {
		log.Fatal("Failed to connect to laporan database:", err)
	}
	defer db.Close()

	if err := db.Ping(); err != nil {
		log.Fatal("Failed to ping laporan database:", err)
	}
	log.Println("Successfully connected to laporan database")

	// Connect to Auth database
	authConnStr := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=disable",
		authDBHost, authDBPort, authDBUser, authDBPassword, authDBName)

	authDB, err = sql.Open("postgres", authConnStr)
	if err != nil {
		log.Fatal("Failed to connect to auth database:", err)
	}
	defer authDB.Close()

	if err := authDB.Ping(); err != nil {
		log.Fatal("Failed to ping auth database:", err)
	}
	log.Println("Successfully connected to auth database")

	// Setup routes - only laporan endpoints
	http.HandleFunc("/laporan/public", corsMiddleware(getPublicLaporanHandler))
	http.HandleFunc("/laporan/my", corsMiddleware(authMiddleware(getMyLaporanHandler)))
	http.HandleFunc("/laporan", corsMiddleware(authMiddleware(createLaporanHandler)))
	http.HandleFunc("/health", healthHandler)

	port := getEnv("PORT", "8080")
	log.Printf("Service Pembuat Laporan starting on port %s\n", port)
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		log.Fatal(err)
	}
}

func corsMiddleware(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		// CORS Headers
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
		w.Header().Set("Access-Control-Expose-Headers", "X-Served-By")

		// Load Balancing visibility - show which pod handled this request
		w.Header().Set("X-Served-By", podHostname)

		// Security Headers
		w.Header().Set("Content-Security-Policy", "default-src 'self'; script-src 'self'; object-src 'none'")
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("X-Frame-Options", "DENY")
		w.Header().Set("X-XSS-Protection", "1; mode=block")
		w.Header().Set("Referrer-Policy", "strict-origin-when-cross-origin")

		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}

		next(w, r)
	}
}

// Middleware to verify JWT token (warga only)
func authMiddleware(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		authHeader := r.Header.Get("Authorization")
		if authHeader == "" || !strings.HasPrefix(authHeader, "Bearer ") {
			log.Println("[AUTH ERROR] No token provided in request")
			http.Error(w, `{"error":"No token provided"}`, http.StatusUnauthorized)
			return
		}

		tokenString := strings.TrimPrefix(authHeader, "Bearer ")
		log.Println("[AUTH] Verifying warga token...")

		claims := &Claims{}
		token, err := jwt.ParseWithClaims(tokenString, claims, func(token *jwt.Token) (interface{}, error) {
			if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
				return nil, fmt.Errorf("unexpected signing method")
			}
			return jwtSecret, nil
		})

		if err != nil || !token.Valid {
			if err == jwt.ErrTokenExpired {
				log.Println("[AUTH ERROR] Token expired:", err)
				http.Error(w, `{"error":"Token expired"}`, http.StatusUnauthorized)
			} else {
				log.Println("[AUTH ERROR] Invalid token:", err)
				http.Error(w, `{"error":"Invalid token"}`, http.StatusUnauthorized)
			}
			return
		}

		// Check if user is 'warga' role (hardcoded in token)
		if claims.Role != "warga" {
			log.Printf("[AUTH ERROR] Access denied - not warga role (role: %s)\n", claims.Role)
			http.Error(w, `{"error":"Access denied. Warga only."}`, http.StatusForbidden)
			return
		}

		// Verify user still exists
		var userID int
		err = authDB.QueryRow("SELECT id FROM users WHERE id = $1", claims.UserID).Scan(&userID)
		if err != nil {
			log.Printf("[AUTH ERROR] User not found in database: userId=%d, error=%v\n", claims.UserID, err)
			http.Error(w, `{"error":"User not found"}`, http.StatusUnauthorized)
			return
		}

		log.Printf("[AUTH SUCCESS] Warga verified: %s (id: %d)\n", claims.NIK, claims.UserID)

		// Store user info in request context (simplified - store in header for this example)
		r.Header.Set("X-User-ID", fmt.Sprintf("%d", claims.UserID))
		r.Header.Set("X-User-NIK", claims.NIK)
		r.Header.Set("X-User-Nama", claims.Nama)

		next(w, r)
	}
}

// PublicLaporan struct for public response
type PublicLaporan struct {
	ID          int       `json:"id"`
	Title       string    `json:"title"`
	Description string    `json:"description"`
	Divisi      string    `json:"divisi"`
	UserNik     string    `json:"user_nik"`
	Status      string    `json:"status"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

// PaginatedResponse for paginated API responses
type PaginatedResponse struct {
	Data       []PublicLaporan `json:"data"`
	Page       int             `json:"page"`
	Limit      int             `json:"limit"`
	TotalItems int             `json:"totalItems"`
	TotalPages int             `json:"totalPages"`
}

// GET /laporan/public - Get all public reports with pagination (no auth required)
func getPublicLaporanHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		log.Println("[GET PUBLIC LAPORAN ERROR] Invalid method:", r.Method)
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Parse pagination parameters
	query := r.URL.Query()
	page := 1
	limit := 10 // Default page size

	if p := query.Get("page"); p != "" {
		if parsed, err := strconv.Atoi(p); err == nil && parsed > 0 {
			page = parsed
		}
	}

	if l := query.Get("limit"); l != "" {
		if parsed, err := strconv.Atoi(l); err == nil && parsed > 0 && parsed <= 100 {
			limit = parsed
		}
	}

	offset := (page - 1) * limit

	log.Printf("[GET PUBLIC LAPORAN] Fetching public reports - page: %d, limit: %d, offset: %d\n", page, limit, offset)

	// Get total count
	var totalItems int
	err := db.QueryRow(`SELECT COUNT(*) FROM laporan WHERE tipe = 'publik'`).Scan(&totalItems)
	if err != nil {
		log.Println("[GET PUBLIC LAPORAN ERROR] Count query error:", err)
		http.Error(w, `{"error":"Failed to count public laporan"}`, http.StatusInternalServerError)
		return
	}

	// Get paginated data
	rows, err := db.Query(`
		SELECT id, title, description, divisi, user_nik, status, created_at, updated_at 
		FROM laporan 
		WHERE tipe = 'publik'
		ORDER BY created_at DESC
		LIMIT $1 OFFSET $2
	`, limit, offset)
	if err != nil {
		log.Println("[GET PUBLIC LAPORAN ERROR] Database query error:", err)
		http.Error(w, `{"error":"Failed to fetch public laporan"}`, http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	var laporanList []PublicLaporan
	for rows.Next() {
		var l PublicLaporan
		if err := rows.Scan(&l.ID, &l.Title, &l.Description, &l.Divisi, &l.UserNik, &l.Status, &l.CreatedAt, &l.UpdatedAt); err != nil {
			log.Println("[GET PUBLIC LAPORAN ERROR] Scan error:", err)
			continue
		}
		laporanList = append(laporanList, l)
	}

	// Calculate total pages
	totalPages := (totalItems + limit - 1) / limit

	response := PaginatedResponse{
		Data:       laporanList,
		Page:       page,
		Limit:      limit,
		TotalItems: totalItems,
		TotalPages: totalPages,
	}

	log.Printf("[GET PUBLIC LAPORAN] Found %d public reports (page %d of %d)\n", len(laporanList), page, totalPages)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// Struct for user's own laporan (includes all fields)
type MyLaporan struct {
	ID          int       `json:"id"`
	Title       string    `json:"title"`
	Description string    `json:"description"`
	Tipe        string    `json:"tipe"`
	Divisi      string    `json:"divisi"`
	Status      string    `json:"status"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

// GET /laporan/my - Get user's own reports (requires auth)
func getMyLaporanHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		log.Println("[GET MY LAPORAN ERROR] Invalid method:", r.Method)
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Get query parameters
	query := r.URL.Query()
	userNik := query.Get("user_nik")
	userHash := query.Get("user_hash")
	filter := query.Get("filter")

	log.Printf("[GET MY LAPORAN] Filter: %s, user_nik: %s, user_hash: %s\n", filter, userNik, userHash)

	var rows *sql.Rows
	var err error

	switch filter {
	case "nik":
		// Get only public & private reports by NIK
		if userNik == "" {
			http.Error(w, `{"error":"user_nik is required for NIK filter"}`, http.StatusBadRequest)
			return
		}
		rows, err = db.Query(`
			SELECT id, title, description, tipe, divisi, status, created_at, updated_at 
			FROM laporan 
			WHERE user_nik = $1 AND tipe IN ('publik', 'private')
			ORDER BY created_at DESC
		`, userNik)

	case "hash":
		// Get only anonim reports by hash
		if userHash == "" {
			http.Error(w, `{"error":"user_hash is required for hash filter"}`, http.StatusBadRequest)
			return
		}
		rows, err = db.Query(`
			SELECT id, title, description, tipe, divisi, status, created_at, updated_at 
			FROM laporan 
			WHERE user_nik = $1 AND tipe = 'anonim'
			ORDER BY created_at DESC
		`, userHash)

	case "all":
		// Get all reports (by NIK for public/private, by hash for anonim)
		if userNik == "" {
			http.Error(w, `{"error":"user_nik is required for all filter"}`, http.StatusBadRequest)
			return
		}
		if userHash != "" {
			// User has both NIK and hash - get all their reports
			rows, err = db.Query(`
				SELECT id, title, description, tipe, divisi, status, created_at, updated_at 
				FROM laporan 
				WHERE (user_nik = $1 AND tipe IN ('publik', 'private')) OR (user_nik = $2 AND tipe = 'anonim')
				ORDER BY created_at DESC
			`, userNik, userHash)
		} else {
			// User only has NIK - get public/private reports
			rows, err = db.Query(`
				SELECT id, title, description, tipe, divisi, status, created_at, updated_at 
				FROM laporan 
				WHERE user_nik = $1 AND tipe IN ('publik', 'private')
				ORDER BY created_at DESC
			`, userNik)
		}

	default:
		// Default: filter by NIK for public/private
		if userNik == "" {
			http.Error(w, `{"error":"user_nik is required"}`, http.StatusBadRequest)
			return
		}
		rows, err = db.Query(`
			SELECT id, title, description, tipe, divisi, status, created_at, updated_at 
			FROM laporan 
			WHERE user_nik = $1 AND tipe IN ('publik', 'private')
			ORDER BY created_at DESC
		`, userNik)
	}

	if err != nil {
		log.Println("[GET MY LAPORAN ERROR] Database query error:", err)
		http.Error(w, `{"error":"Failed to fetch laporan"}`, http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	var laporanList []MyLaporan
	for rows.Next() {
		var l MyLaporan
		if err := rows.Scan(&l.ID, &l.Title, &l.Description, &l.Tipe, &l.Divisi, &l.Status, &l.CreatedAt, &l.UpdatedAt); err != nil {
			log.Println("[GET MY LAPORAN ERROR] Scan error:", err)
			continue
		}
		laporanList = append(laporanList, l)
	}

	log.Printf("[GET MY LAPORAN] Found %d reports\n", len(laporanList))

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(laporanList)
}

func createLaporanHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		log.Println("[CREATE LAPORAN ERROR] Invalid method:", r.Method)
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req CreateLaporanRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		log.Println("[CREATE LAPORAN ERROR] Invalid request body:", err)
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	userNIK := r.Header.Get("X-User-NIK")
	userNama := r.Header.Get("X-User-Nama")
	// Don't log NIK for anonim reports - will check tipe after parsing request

	// Validate input
	if req.Title == "" || req.Description == "" {
		log.Println("[CREATE LAPORAN ERROR] Missing title or description")
		http.Error(w, "Title and description are required", http.StatusBadRequest)
		return
	}

	// Validate tipe enum
	validTipe := map[string]bool{"publik": true, "private": true, "anonim": true}
	if !validTipe[req.Tipe] {
		log.Println("[CREATE LAPORAN ERROR] Invalid tipe:", req.Tipe)
		http.Error(w, "Tipe must be one of: publik, private, anonim", http.StatusBadRequest)
		return
	}

	// Validate divisi enum
	validDivisi := map[string]bool{"kebersihan": true, "kesehatan": true, "fasilitas umum": true, "kriminalitas": true}
	if !validDivisi[req.Divisi] {
		log.Println("[CREATE LAPORAN ERROR] Invalid divisi:", req.Divisi)
		http.Error(w, "Divisi must be one of: kebersihan, kesehatan, fasilitas umum, kriminalitas", http.StatusBadRequest)
		return
	}

	// Determine user identifier to store
	// For anonim reports, use the hash provided by frontend (NIK+password hashed client-side)
	// Server never sees the password - only the hash
	var userIdentifier string
	if req.Tipe == "anonim" {
		if req.UserNikHash == "" {
			log.Println("[CREATE LAPORAN ERROR] userNikHash required for anonymous reports")
			http.Error(w, "Hash NIK+password diperlukan untuk laporan anonim", http.StatusBadRequest)
			return
		}
		userIdentifier = req.UserNikHash
		log.Printf("[CREATE LAPORAN] Anonim report - using client-side hash\n")
	} else {
		userIdentifier = userNIK
	}

	// Insert into database
	var id int
	err := db.QueryRow(
		"INSERT INTO laporan (title, description, tipe, divisi, user_nik, status) VALUES ($1, $2, $3, $4, $5, $6) RETURNING id",
		req.Title, req.Description, req.Tipe, req.Divisi, userIdentifier, "pending",
	).Scan(&id)

	if err != nil {
		log.Println("[CREATE LAPORAN ERROR] Database error:", err)
		http.Error(w, "Failed to create laporan", http.StatusInternalServerError)
		return
	}

	// Return created laporan
	laporan := Laporan{
		ID:          id,
		Title:       req.Title,
		Description: req.Description,
		Tipe:        req.Tipe,
		Divisi:      req.Divisi,
		Status:      "pending",
	}

	// Log success - hide NIK for anonim reports
	if req.Tipe == "anonim" {
		log.Printf("[CREATE LAPORAN SUCCESS] Created ANONIM laporan with ID: %d (identity protected)\n", id)
	} else {
		log.Printf("[CREATE LAPORAN SUCCESS] Created laporan with ID: %d by warga %s (%s)\n", id, userNama, userNIK)
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(laporan)
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "healthy"})
}

func getEnv(key, defaultValue string) string {
	value := os.Getenv(key)
	if value == "" {
		return defaultValue
	}
	return value
}

// Parse duration string (e.g., "15m", "7d")
func parseDuration(s string) (time.Duration, error) {
	if len(s) < 2 {
		return 0, fmt.Errorf("invalid duration format")
	}

	value := s[:len(s)-1]
	unit := s[len(s)-1:]

	var multiplier time.Duration
	switch unit {
	case "s":
		multiplier = time.Second
	case "m":
		multiplier = time.Minute
	case "h":
		multiplier = time.Hour
	case "d":
		multiplier = 24 * time.Hour
	default:
		return time.ParseDuration(s) // fallback to standard parsing
	}

	var num int
	_, err := fmt.Sscanf(value, "%d", &num)
	if err != nil {
		return 0, err
	}

	return time.Duration(num) * multiplier, nil
}
