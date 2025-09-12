# 🍚 FoodBridge Backend

Backend สำหรับโปรเจกต์ **FoodBridge** (แจกข้าวฟรี)  
พัฒนาโดยใช้ภาษา **Go (Echo Framework)** + **Postgres (Docker)**  

---

## 🚀 โครงสร้างโปรเจกต์

FoodBridge/
├── app/ # Dependency Injection (Deps)
├── config/ # โหลดค่าการตั้งค่า (.env)
├── databases/ # การเชื่อมต่อฐานข้อมูล
├── dto/ # Data Transfer Object
├── entities/ # Struct ของ DB
├── pkg/ # business logic แยกตาม feature (auth, booking, post ...)
├── server/ # router และ middleware
├── .env.example # ตัวอย่างไฟล์ config
├── docker-compose.yml # docker run postgres + adminer
├── Dockerfile # build backend เป็น container
├── go.mod / go.sum # dependency ของ Go
└── main.go # entrypoint ของระบบ


---

## 🛠️ สิ่งที่ต้องติดตั้งก่อน

- [Go](https://go.dev/) (>= 1.21)  
- [Docker Desktop](https://www.docker.com/products/docker-desktop/)  
- [Git](https://git-scm.com/)  

---

## ⚙️ วิธีรันโปรเจกต์บนเครื่อง

### 1. Clone repo
git clone https://github.com/RathaTart/FoodBridge.git
cd FoodBridge

### 2. สร้างไฟล์ .env
คัดลอกจาก .env.example

### 3. รัน Database ด้วย Docker
docker compose up -d

### 4. ติดตั้ง dependency Go
go mod tidy

### 5. รันเซิร์ฟเวอร์
go run ./main.go

### 5. ทดสอบ Health Check
curl http://localhost:8080/health
คาดว่าจะได้:
HTTP/1.1 200 OK
ok



