#!/bin/bash
# =============================================================================
# Database Seeding Script
# Mengisi database dengan data sample untuk testing/development
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}"
echo "╔═══════════════════════════════════════════════════════════════════════════════╗"
echo "║                    DATABASE SEEDING SCRIPT                                    ║"
echo "║                    Sistem Laporan Masyarakat                                  ║"
echo "╚═══════════════════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Get pod names
POSTGRES_WARGA=$(kubectl get pods -l app=postgres-warga -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
POSTGRES_ADMIN=$(kubectl get pods -l app=postgres-admin -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
POSTGRES_LAPORAN=$(kubectl get pods -l app=postgres-laporan -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -z "$POSTGRES_WARGA" ] || [ -z "$POSTGRES_ADMIN" ] || [ -z "$POSTGRES_LAPORAN" ]; then
    echo -e "${RED}❌ Error: Database pods not found. Make sure all pods are running.${NC}"
    echo "Run: kubectl get pods"
    exit 1
fi

echo -e "${GREEN}Found database pods:${NC}"
echo "  - Warga DB:   $POSTGRES_WARGA"
echo "  - Admin DB:   $POSTGRES_ADMIN"
echo "  - Laporan DB: $POSTGRES_LAPORAN"
echo ""

# =============================================================================
# Seed Warga Users
# =============================================================================
echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}  SEEDING: Users Warga${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"

# Password: Password123! (bcrypt hash)
BCRYPT_HASH='$2a$10$bh.jxcRwlNfDo3J9uOg7wOsCcMcLvzdHcsPUlcvN/KsMB50iz/RGe'

kubectl exec -i $POSTGRES_WARGA -- psql -U postgres -d wargadb << 'EOSQL'
-- Clear existing data (optional, comment out if you want to keep existing)
-- TRUNCATE users CASCADE;

-- Insert sample warga users
-- Password for all: Password123!
INSERT INTO users (nik, nama, email, password_hash) VALUES
    ('3201010101010001', 'Budi Santoso', 'budi.santoso@email.com', '$2a$10$bh.jxcRwlNfDo3J9uOg7wOsCcMcLvzdHcsPUlcvN/KsMB50iz/RGe'),
    ('3201010101010002', 'Siti Aminah', 'siti.aminah@email.com', '$2a$10$bh.jxcRwlNfDo3J9uOg7wOsCcMcLvzdHcsPUlcvN/KsMB50iz/RGe'),
    ('3201010101010003', 'Ahmad Hidayat', 'ahmad.hidayat@email.com', '$2a$10$bh.jxcRwlNfDo3J9uOg7wOsCcMcLvzdHcsPUlcvN/KsMB50iz/RGe'),
    ('3201010101010004', 'Dewi Lestari', 'dewi.lestari@email.com', '$2a$10$bh.jxcRwlNfDo3J9uOg7wOsCcMcLvzdHcsPUlcvN/KsMB50iz/RGe'),
    ('3201010101010005', 'Rudi Hermawan', 'rudi.hermawan@email.com', '$2a$10$bh.jxcRwlNfDo3J9uOg7wOsCcMcLvzdHcsPUlcvN/KsMB50iz/RGe'),
    ('3201010101010006', 'Maya Sari', 'maya.sari@email.com', '$2a$10$bh.jxcRwlNfDo3J9uOg7wOsCcMcLvzdHcsPUlcvN/KsMB50iz/RGe'),
    ('3201010101010007', 'Joko Widodo', 'joko.widodo@email.com', '$2a$10$bh.jxcRwlNfDo3J9uOg7wOsCcMcLvzdHcsPUlcvN/KsMB50iz/RGe'),
    ('3201010101010008', 'Rina Marlina', 'rina.marlina@email.com', '$2a$10$bh.jxcRwlNfDo3J9uOg7wOsCcMcLvzdHcsPUlcvN/KsMB50iz/RGe'),
    ('3201010101010009', 'Eko Prasetyo', 'eko.prasetyo@email.com', '$2a$10$bh.jxcRwlNfDo3J9uOg7wOsCcMcLvzdHcsPUlcvN/KsMB50iz/RGe'),
    ('3201010101010010', 'Fitri Handayani', 'fitri.handayani@email.com', '$2a$10$bh.jxcRwlNfDo3J9uOg7wOsCcMcLvzdHcsPUlcvN/KsMB50iz/RGe')
ON CONFLICT (nik) DO NOTHING;

SELECT COUNT(*) as total_warga FROM users;
EOSQL

echo -e "${GREEN}✅ Warga users seeded${NC}"

# =============================================================================
# Seed Admin Users
# =============================================================================
echo ""
echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}  SEEDING: Users Admin${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"

kubectl exec -i $POSTGRES_ADMIN -- psql -U postgres -d admindb << 'EOSQL'
-- Insert sample admin users
-- Password for all: Password123!
INSERT INTO users (nip, nama, email, password_hash, divisi) VALUES
    ('199001012020011001', 'Admin Kebersihan 1', 'admin.kebersihan1@pemda.go.id', '$2a$10$bh.jxcRwlNfDo3J9uOg7wOsCcMcLvzdHcsPUlcvN/KsMB50iz/RGe', 'kebersihan'),
    ('199001012020011002', 'Admin Kebersihan 2', 'admin.kebersihan2@pemda.go.id', '$2a$10$bh.jxcRwlNfDo3J9uOg7wOsCcMcLvzdHcsPUlcvN/KsMB50iz/RGe', 'kebersihan'),
    ('199002022020012001', 'Admin Kesehatan 1', 'admin.kesehatan1@pemda.go.id', '$2a$10$bh.jxcRwlNfDo3J9uOg7wOsCcMcLvzdHcsPUlcvN/KsMB50iz/RGe', 'kesehatan'),
    ('199002022020012002', 'Admin Kesehatan 2', 'admin.kesehatan2@pemda.go.id', '$2a$10$bh.jxcRwlNfDo3J9uOg7wOsCcMcLvzdHcsPUlcvN/KsMB50iz/RGe', 'kesehatan'),
    ('199003032020013001', 'Admin Fasum 1', 'admin.fasum1@pemda.go.id', '$2a$10$bh.jxcRwlNfDo3J9uOg7wOsCcMcLvzdHcsPUlcvN/KsMB50iz/RGe', 'fasilitas umum'),
    ('199003032020013002', 'Admin Fasum 2', 'admin.fasum2@pemda.go.id', '$2a$10$bh.jxcRwlNfDo3J9uOg7wOsCcMcLvzdHcsPUlcvN/KsMB50iz/RGe', 'fasilitas umum'),
    ('199004042020014001', 'Admin Kriminal 1', 'admin.kriminal1@pemda.go.id', '$2a$10$bh.jxcRwlNfDo3J9uOg7wOsCcMcLvzdHcsPUlcvN/KsMB50iz/RGe', 'kriminalitas'),
    ('199004042020014002', 'Admin Kriminal 2', 'admin.kriminal2@pemda.go.id', '$2a$10$bh.jxcRwlNfDo3J9uOg7wOsCcMcLvzdHcsPUlcvN/KsMB50iz/RGe', 'kriminalitas')
ON CONFLICT (nip) DO NOTHING;

SELECT divisi, COUNT(*) as jumlah FROM users GROUP BY divisi ORDER BY divisi;
EOSQL

echo -e "${GREEN}✅ Admin users seeded${NC}"

# =============================================================================
# Seed Laporan
# =============================================================================
echo ""
echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}  SEEDING: Laporan${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"

kubectl exec -i $POSTGRES_LAPORAN -- psql -U postgres -d laporandb << 'EOSQL'
-- Insert sample laporan
INSERT INTO laporan (title, description, tipe, divisi, user_nik, status) VALUES
    -- Laporan Kebersihan
    ('Sampah Menumpuk di Jalan Merdeka', 'Terdapat tumpukan sampah yang sudah berhari-hari tidak diangkut di Jalan Merdeka No. 45. Bau sudah menyengat dan mengganggu warga sekitar.', 'publik', 'kebersihan', '3201010101010001', 'pending'),
    ('Got Tersumbat di Perumahan Griya Asri', 'Got di depan rumah blok C-12 tersumbat dan menyebabkan genangan air saat hujan.', 'publik', 'kebersihan', '3201010101010002', 'in_progress'),
    ('Tempat Sampah Rusak di Taman Kota', 'Tempat sampah di taman kota bagian timur sudah rusak dan perlu diganti.', 'publik', 'kebersihan', '3201010101010003', 'completed'),
    ('Sampah Liar di Lahan Kosong', 'Ada pembuangan sampah liar di lahan kosong belakang pasar. Mohon ditindaklanjuti.', 'anonim', 'kebersihan', 'a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6a7b8', 'pending'),
    
    -- Laporan Kesehatan
    ('Puskesmas Kekurangan Obat', 'Puskesmas Kelurahan Sukamaju kehabisan stok obat dasar seperti paracetamol dan amoxicillin.', 'publik', 'kesehatan', '3201010101010004', 'in_progress'),
    ('Fogging Demam Berdarah', 'Mohon dilakukan fogging di RT 05/RW 03 karena sudah ada 3 kasus DBD dalam sebulan terakhir.', 'publik', 'kesehatan', '3201010101010005', 'pending'),
    ('Air PDAM Keruh', 'Air PDAM di daerah Cilandak sudah seminggu keruh dan berbau. Mohon dicek kualitasnya.', 'publik', 'kesehatan', '3201010101010006', 'pending'),
    ('Makanan Kadaluarsa di Warung', 'Ditemukan makanan kemasan kadaluarsa dijual di warung dekat sekolah SDN 01.', 'anonim', 'kesehatan', 'b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6a7b8c9', 'in_progress'),
    
    -- Laporan Fasilitas Umum
    ('Lampu Jalan Mati', 'Lampu penerangan jalan di Jl. Sudirman KM 5 sudah mati selama 2 minggu. Membahayakan pengguna jalan malam hari.', 'publik', 'fasilitas umum', '3201010101010007', 'pending'),
    ('Jalan Berlubang Besar', 'Terdapat lubang besar di Jl. Gatot Subroto yang sudah memakan korban kecelakaan motor.', 'publik', 'fasilitas umum', '3201010101010008', 'in_progress'),
    ('Taman Bermain Rusak', 'Ayunan dan perosotan di taman bermain kelurahan sudah rusak dan berbahaya untuk anak-anak.', 'publik', 'fasilitas umum', '3201010101010009', 'completed'),
    ('Jembatan Penyeberangan Rapuh', 'Jembatan penyeberangan orang di depan mall sudah kropos dan berbunyi saat diinjak.', 'publik', 'fasilitas umum', '3201010101010010', 'pending'),
    ('Halte Bus Tanpa Atap', 'Halte bus di Jl. Diponegoro atapnya hilang sehingga penumpang kehujanan.', 'anonim', 'fasilitas umum', 'c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6a7b8c9d0', 'pending'),
    
    -- Laporan Kriminalitas
    ('Pencurian Motor Marak', 'Dalam sebulan terakhir sudah 5 motor hilang di area parkir pasar. Mohon patroli ditingkatkan.', 'publik', 'kriminalitas', '3201010101010001', 'in_progress'),
    ('Pencopetan di Angkot', 'Sering terjadi pencopetan di angkot jurusan Terminal-Stasiun. Mohon ada petugas di halte.', 'anonim', 'kriminalitas', 'd4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6a7b8c9d0e1', 'pending'),
    ('Perjudian di Gang Sempit', 'Ada kegiatan perjudian rutin setiap malam di gang sempit belakang warnet.', 'anonim', 'kriminalitas', 'e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6a7b8c9d0e1f2', 'pending'),
    ('Preman Minta Uang Keamanan', 'Sekelompok preman meminta uang keamanan paksa kepada pedagang kaki lima di area stasiun.', 'anonim', 'kriminalitas', 'f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6a7b8c9d0e1f2g3', 'in_progress'),
    ('Vandalisme di Fasilitas Umum', 'Fasilitas umum seperti halte dan taman sering dicoret-coret oleh oknum tidak bertanggung jawab.', 'publik', 'kriminalitas', '3201010101010002', 'pending'),
    
    -- Additional mixed reports
    ('Trotoar Rusak Parah', 'Trotoar di sepanjang Jl. Asia Afrika rusak parah, berbahaya untuk pejalan kaki dan difabel.', 'publik', 'fasilitas umum', '3201010101010003', 'pending'),
    ('Banjir Rutin Saat Hujan', 'Setiap hujan lebat, area perumahan kami selalu banjir setinggi lutut. Mohon perbaikan drainase.', 'publik', 'fasilitas umum', '3201010101010004', 'in_progress')
ON CONFLICT DO NOTHING;

-- Show summary
SELECT divisi, status, COUNT(*) as jumlah 
FROM laporan 
GROUP BY divisi, status 
ORDER BY divisi, status;

SELECT 'Total Laporan:' as info, COUNT(*) as jumlah FROM laporan;
EOSQL

echo -e "${GREEN}✅ Laporan seeded${NC}"

# =============================================================================
# Summary
# =============================================================================
echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  SEEDING COMPLETE!${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${GREEN}📊 Summary:${NC}"
echo ""
echo -e "  ${WHITE}Users Warga:${NC}"
echo "    - 10 sample users created"
echo "    - Password: Password123!"
echo "    - NIK: 3201010101010001 - 3201010101010010"
echo ""
echo -e "  ${WHITE}Users Admin:${NC}"
echo "    - 8 admin users (2 per divisi)"
echo "    - Password: Password123!"
echo "    - Divisi: kebersihan, kesehatan, fasilitas umum, kriminalitas"
echo ""
echo -e "  ${WHITE}Laporan:${NC}"
echo "    - 20 sample laporan"
echo "    - Mix of publik and anonim types"
echo "    - Various statuses: pending, in_progress, completed"
echo ""
echo -e "${YELLOW}💡 Quick Login:${NC}"
echo "    Warga:  NIK=3201010101010001, Password=Password123!"
echo "    Admin:  NIP=199001012020011001, Password=Password123!"
echo ""
echo -e "${GREEN}✅ Database seeding completed successfully!${NC}"
