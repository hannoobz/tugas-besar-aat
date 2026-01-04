// Code generated with the assistance of Claude Sonnet for implementation logic

package main

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"golang.org/x/crypto/bcrypt"
	_ "github.com/lib/pq"
)

type User struct {
	ID           int       `json:"id"`
	NIK          string    `json:"nik"`
	Nama         string    `json:"nama"`
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
	UserID int    `json:"userId"`
	NIK    string `json:"nik"`
	Nama   string `json:"nama"`
	Role   string `json:"role"`
	jwt.RegisteredClaims
}

type RefreshClaims struct {
	UserID int `json:"userId"`
	jwt.RegisteredClaims
}

var db *sql.DB

// JWT Configuration
var jwtSecret []byte
var jwtRefreshSecret []byte
var jwtAccessExpiry string
var jwtRefreshExpiry string

func main() {
	// Get database connection details from environment
	dbHost := getEnv("DB_HOST", "postgres-warga")
	dbPort := getEnv("DB_PORT", "5432")
	dbUser := getEnv("DB_USER", "postgres")
	dbPassword := getEnv("DB_PASSWORD", "postgres")
	dbName := getEnv("DB_NAME", "wargadb")

	// JWT Configuration
	jwtSecret = []byte(getEnv("JWT_SECRET", "your-secret-key"))
	jwtRefreshSecret = []byte(getEnv("JWT_REFRESH_SECRET", "your-refresh-secret"))
	jwtAccessExpiry = getEnv("JWT_ACCESS_EXPIRY", "15m")
	jwtRefreshExpiry = getEnv("JWT_REFRESH_EXPIRY", "7d")

	// Connect to PostgreSQL
	connStr := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=disable",
		dbHost, dbPort, dbUser, dbPassword, dbName)

	var err error
	db, err = sql.Open("postgres", connStr)
	if err != nil {
		log.Fatal("Failed to connect to warga database:", err)
	}
	defer db.Close()

	if err := db.Ping(); err != nil {
		log.Fatal("Failed to ping warga database:", err)
	}
	log.Println("Successfully connected to warga database")

	// Setup routes
	http.HandleFunc("/auth/register", corsMiddleware(registerHandler))
	http.HandleFunc("/auth/login", corsMiddleware(loginHandler))
	http.HandleFunc("/auth/verify", corsMiddleware(verifyTokenHandler))
	http.HandleFunc("/auth/verify-password", corsMiddleware(verifyPasswordHandler))
	http.HandleFunc("/auth/refresh", corsMiddleware(refreshTokenHandler))
	http.HandleFunc("/auth/logout", corsMiddleware(logoutHandler))
	http.HandleFunc("/health", healthHandler)

	port := getEnv("PORT", "8081")
	log.Printf("Service Auth Warga starting on port %s\n", port)
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		log.Fatal(err)
	}
}

func corsMiddleware(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
		w.Header().Set("Content-Security-Policy", "default-src 'self'; script-src 'self'; object-src 'none'")
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("X-Frame-Options", "DENY")

		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}
		next(w, r)
	}
}

func registerHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req RegisterRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"Invalid request body"}`, http.StatusBadRequest)
		return
	}

	log.Printf("[REGISTER] Attempt to register warga: %s\n", req.NIK)

	if req.NIK == "" || req.Nama == "" || req.Email == "" || req.Password == "" {
		http.Error(w, `{"error":"NIK, nama, email, and password are required"}`, http.StatusBadRequest)
		return
	}

	if len(req.NIK) != 16 {
		http.Error(w, `{"error":"NIK must be exactly 16 digits"}`, http.StatusBadRequest)
		return
	}

	// Check if NIK or email already exists
	var existingID int
	err := db.QueryRow("SELECT id FROM users WHERE nik = $1 OR email = $2", req.NIK, req.Email).Scan(&existingID)
	if err == nil {
		http.Error(w, `{"error":"NIK or email already exists"}`, http.StatusConflict)
		return
	}

	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		http.Error(w, `{"error":"Failed to hash password"}`, http.StatusInternalServerError)
		return
	}

	var user User
	err = db.QueryRow(
		"INSERT INTO users (nik, nama, email, password_hash) VALUES ($1, $2, $3, $4) RETURNING id, nik, nama, email, created_at",
		req.NIK, req.Nama, req.Email, string(hashedPassword),
	).Scan(&user.ID, &user.NIK, &user.Nama, &user.Email, &user.CreatedAt)

	if err != nil {
		http.Error(w, `{"error":"Failed to register user"}`, http.StatusInternalServerError)
		return
	}

	log.Printf("[REGISTER SUCCESS] New warga registered: %s (id: %d)\n", user.NIK, user.ID)

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(map[string]interface{}{
		"message": "User registered successfully",
		"user": map[string]interface{}{
			"id":         user.ID,
			"nik":        user.NIK,
			"nama":       user.Nama,
			"email":      user.Email,
			"role":       "warga",
			"created_at": user.CreatedAt,
		},
	})
}

func loginHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req LoginRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"Invalid request body"}`, http.StatusBadRequest)
		return
	}

	log.Printf("[LOGIN] Warga login attempt: %s\n", req.NIK)

	if req.NIK == "" || req.Password == "" {
		http.Error(w, `{"error":"NIK and password are required"}`, http.StatusBadRequest)
		return
	}

	var user User
	err := db.QueryRow(
		"SELECT id, nik, nama, email, password_hash FROM users WHERE nik = $1",
		req.NIK,
	).Scan(&user.ID, &user.NIK, &user.Nama, &user.Email, &user.PasswordHash)

	if err != nil {
		http.Error(w, `{"error":"Invalid credentials"}`, http.StatusUnauthorized)
		return
	}

	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(req.Password)); err != nil {
		http.Error(w, `{"error":"Invalid credentials"}`, http.StatusUnauthorized)
		return
	}

	accessDuration, _ := parseDuration(jwtAccessExpiry)
	refreshDuration, _ := parseDuration(jwtRefreshExpiry)

	accessToken := jwt.NewWithClaims(jwt.SigningMethodHS256, Claims{
		UserID: user.ID,
		NIK:    user.NIK,
		Nama:   user.Nama,
		Role:   "warga",
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(accessDuration)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
		},
	})

	accessTokenString, err := accessToken.SignedString(jwtSecret)
	if err != nil {
		http.Error(w, `{"error":"Failed to generate token"}`, http.StatusInternalServerError)
		return
	}

	refreshToken := jwt.NewWithClaims(jwt.SigningMethodHS256, RefreshClaims{
		UserID: user.ID,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(refreshDuration)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
		},
	})

	refreshTokenString, err := refreshToken.SignedString(jwtRefreshSecret)
	if err != nil {
		http.Error(w, `{"error":"Failed to generate refresh token"}`, http.StatusInternalServerError)
		return
	}

	expiresAt := time.Now().Add(refreshDuration)
	_, err = db.Exec(
		"INSERT INTO refresh_tokens (user_id, token, expires_at) VALUES ($1, $2, $3)",
		user.ID, refreshTokenString, expiresAt,
	)

	if err != nil {
		http.Error(w, `{"error":"Failed to store refresh token"}`, http.StatusInternalServerError)
		return
	}

	log.Printf("[LOGIN SUCCESS] Warga logged in: %s\n", user.NIK)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"message":      "Login successful",
		"accessToken":  accessTokenString,
		"refreshToken": refreshTokenString,
		"user": map[string]interface{}{
			"id":    user.ID,
			"nik":   user.NIK,
			"nama":  user.Nama,
			"email": user.Email,
			"role":  "warga",
		},
	})
}

func verifyTokenHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	authHeader := r.Header.Get("Authorization")
	if authHeader == "" || !strings.HasPrefix(authHeader, "Bearer ") {
		http.Error(w, `{"error":"No token provided"}`, http.StatusUnauthorized)
		return
	}

	tokenString := strings.TrimPrefix(authHeader, "Bearer ")
	claims := &Claims{}
	token, err := jwt.ParseWithClaims(tokenString, claims, func(token *jwt.Token) (interface{}, error) {
		return jwtSecret, nil
	})

	if err != nil || !token.Valid {
		http.Error(w, `{"error":"Invalid token"}`, http.StatusUnauthorized)
		return
	}

	var user User
	err = db.QueryRow(
		"SELECT id, nik, nama, email FROM users WHERE id = $1",
		claims.UserID,
	).Scan(&user.ID, &user.NIK, &user.Nama, &user.Email)

	if err != nil {
		http.Error(w, `{"error":"User not found"}`, http.StatusUnauthorized)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"valid": true,
		"user": map[string]interface{}{
			"id":    user.ID,
			"nik":   user.NIK,
			"nama":  user.Nama,
			"email": user.Email,
			"role":  "warga",
		},
	})
}

func refreshTokenHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req RefreshTokenRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"Invalid request body"}`, http.StatusBadRequest)
		return
	}

	if req.RefreshToken == "" {
		http.Error(w, `{"error":"Refresh token is required"}`, http.StatusBadRequest)
		return
	}

	claims := &RefreshClaims{}
	token, err := jwt.ParseWithClaims(req.RefreshToken, claims, func(token *jwt.Token) (interface{}, error) {
		return jwtRefreshSecret, nil
	})

	if err != nil || !token.Valid {
		http.Error(w, `{"error":"Invalid refresh token"}`, http.StatusUnauthorized)
		return
	}

	var tokenID int
	var revoked bool
	var expiresAt time.Time
	err = db.QueryRow(
		"SELECT id, revoked, expires_at FROM refresh_tokens WHERE token = $1",
		req.RefreshToken,
	).Scan(&tokenID, &revoked, &expiresAt)

	if err != nil || revoked || expiresAt.Before(time.Now()) {
		http.Error(w, `{"error":"Invalid or expired refresh token"}`, http.StatusUnauthorized)
		return
	}

	var user User
	err = db.QueryRow(
		"SELECT id, nik, nama, email FROM users WHERE id = $1",
		claims.UserID,
	).Scan(&user.ID, &user.NIK, &user.Nama, &user.Email)

	if err != nil {
		http.Error(w, `{"error":"User not found"}`, http.StatusUnauthorized)
		return
	}

	accessDuration, _ := parseDuration(jwtAccessExpiry)
	accessToken := jwt.NewWithClaims(jwt.SigningMethodHS256, Claims{
		UserID: user.ID,
		NIK:    user.NIK,
		Nama:   user.Nama,
		Role:   "warga",
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(accessDuration)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
		},
	})

	accessTokenString, err := accessToken.SignedString(jwtSecret)
	if err != nil {
		http.Error(w, `{"error":"Failed to generate token"}`, http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"accessToken": accessTokenString,
		"user": map[string]interface{}{
			"id":    user.ID,
			"nik":   user.NIK,
			"nama":  user.Nama,
			"email": user.Email,
			"role":  "warga",
		},
	})
}

func logoutHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req RefreshTokenRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"Invalid request body"}`, http.StatusBadRequest)
		return
	}

	if req.RefreshToken == "" {
		http.Error(w, `{"error":"Refresh token is required"}`, http.StatusBadRequest)
		return
	}

	_, err := db.Exec("UPDATE refresh_tokens SET revoked = TRUE WHERE token = $1", req.RefreshToken)
	if err != nil {
		http.Error(w, `{"error":"Failed to logout"}`, http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"message": "Logout successful"})
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

// verifyPasswordHandler - Verify password without generating new tokens
// Used for anonim report submission to validate user password
func verifyPasswordHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Get token from Authorization header
	authHeader := r.Header.Get("Authorization")
	if authHeader == "" || len(authHeader) < 8 {
		http.Error(w, `{"error":"No token provided"}`, http.StatusUnauthorized)
		return
	}

	tokenString := authHeader[7:] // Remove "Bearer "

	// Parse and validate token
	token, err := jwt.ParseWithClaims(tokenString, &Claims{}, func(token *jwt.Token) (interface{}, error) {
		return jwtSecret, nil
	})

	if err != nil || !token.Valid {
		http.Error(w, `{"error":"Invalid token"}`, http.StatusUnauthorized)
		return
	}

	claims, ok := token.Claims.(*Claims)
	if !ok {
		http.Error(w, `{"error":"Invalid token claims"}`, http.StatusUnauthorized)
		return
	}

	// Get password from request body
	var req struct {
		Password string `json:"password"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"Invalid request body"}`, http.StatusBadRequest)
		return
	}

	if req.Password == "" {
		http.Error(w, `{"error":"Password is required"}`, http.StatusBadRequest)
		return
	}

	log.Printf("[VERIFY PASSWORD] Verifying password for user: %s\n", claims.NIK)

	// Get user's password hash from database
	var passwordHash string
	err = db.QueryRow(
		"SELECT password_hash FROM users WHERE nik = $1",
		claims.NIK,
	).Scan(&passwordHash)

	if err != nil {
		log.Printf("[VERIFY PASSWORD ERROR] User not found: %s\n", claims.NIK)
		http.Error(w, `{"error":"User not found"}`, http.StatusUnauthorized)
		return
	}

	// Compare password
	if err := bcrypt.CompareHashAndPassword([]byte(passwordHash), []byte(req.Password)); err != nil {
		log.Printf("[VERIFY PASSWORD ERROR] Invalid password for user: %s\n", claims.NIK)
		http.Error(w, `{"error":"Invalid password"}`, http.StatusUnauthorized)
		return
	}

	log.Printf("[VERIFY PASSWORD SUCCESS] Password verified for user: %s\n", claims.NIK)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"valid":   true,
		"message": "Password verified successfully",
	})
}

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
		return time.ParseDuration(s)
	}

	var num int
	fmt.Sscanf(value, "%d", &num)
	return time.Duration(num) * multiplier, nil
}
