# EventFund Ticket Platform

Nền tảng tạo quỹ sự kiện, bán, trao đổi và chứng thực vé sự kiện trên blockchain.

## Kiến trúc

```
eventfund-ticket-platform/
├── frontend/          # React + Vite
├── backend/           # Express.js API
└── contracts/         # Solidity Smart Contracts (Hardhat)
```

## Tech Stack

### Frontend

- React 19
- Vite 7
- ESLint

### Backend

- Express.js 5
- MongoDB (Mongoose)
- Redis (ioredis)
- Helmet (Security)

### Smart Contracts

- Solidity
- Hardhat
- Hardhat Toolbox

## Cài đặt

### Yêu cầu

- Node.js >= 18
- MongoDB
- Redis

### 1. Clone repository

```bash
git clone https://github.com/kieuphat159/Eventfund-platform.git
cd eventfund-ticket-platform
```

### 2. Cài đặt dependencies

```bash
# Cài đặt tất cả
npm install
npm install --prefix backend
npm install --prefix frontend
npm install --prefix contracts
```

### 3. Cấu hình môi trường

Tạo file `.env` trong thư mục `backend/`:

```env
PORT=3000
MONGODB_URI=mongodb://localhost:27017/eventfund
REDIS_URL=redis://localhost:6379
```

Tạo file `.env` trong thư mục `contracts/`:

```env
PRIVATE_KEY=your_wallet_private_key
```

## Chạy ứng dụng

### Development

```bash
# Chạy cả frontend và backend
npm run dev

# Hoặc chạy riêng từng phần
npm run frontend dev      # Frontend tại http://localhost:5173
npm run backend dev       # Backend tại http://localhost:3000
```

### Smart Contracts

```bash
# Compile contracts
npm run contracts compile

# Chạy tests
npm run contracts test

# Deploy (local)
npm run contracts node          # Chạy local node
npm run contracts ignition deploy ./ignition/modules/Lock.js
```

## Cấu trúc chi tiết

### Backend (`/backend`)

```
backend/
└── src/
    ├── app.js          # Express app config
    ├── server.js       # Server entry point
    ├── config/         # Database, Redis config
    ├── modules/        # Feature modules
    ├── routes/         # API routes
    └── utils/          # Helper functions
```

### Frontend (`/frontend`)

```
frontend/
└── src/
    ├── main.jsx        # Entry point
    ├── App.jsx         # Root component
    ├── assets/         # Static assets
    └── ...
```

### Contracts (`/contracts`)

```
contracts/
├── contracts/
│   ├── Fund.sol        # Crowdfunding contract
│   ├── Ticket.sol      # NFT Ticket contract
│   └── Marketplace.sol # Ticket marketplace
├── test/               # Contract tests
└── ignition/           # Deployment scripts
```

## Smart Contracts

| Contract          | Mô tả                       |
| ----------------- | --------------------------- |
| `Fund.sol`        | Quản lý gây quỹ cho sự kiện |
| `Ticket.sol`      | NFT ticket cho sự kiện      |
| `Marketplace.sol` | Sàn giao dịch vé            |

## Testing

```bash
# Backend tests
npm run backend test

# Contract tests
npm run contracts test
```
