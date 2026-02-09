import mongoose from 'mongoose';

let isConnected = false;

//Hàm Listener
const setupEventListeners = () => {
  if (mongoose.connection.listeners('error').length > 0) return;

  mongoose.connection.on('disconnected', () => {
    console.warn('MongoDB disconnected');
    isConnected = false;
  });

  mongoose.connection.on('reconnected', () => {
    console.log('MongoDB reconnected');
    isConnected = true;
  });

  mongoose.connection.on('error', (err) => {
    console.error('MongoDB error:', err.message);
  });
};

//Hàm Connect
export const connectDB = async () => {
  //Nếu đã kết nối rồi thì return luôn
  if (isConnected && mongoose.connection.readyState === 1) {
    console.log('Sử dụng kết nối MongoDB hiện có');
    return mongoose.connection;
  }

  try {
    const uri = process.env.NODE_ENV === 'PROD'
      ? process.env.MONGO_PROD_URI
      : process.env.MONGO_DEV_URI;

    if (!uri) throw new Error('Cấu hình MONGO_URI thiếu trong .env');

    // Thực hiện kết nối
    const conn = await mongoose.connect(uri);

    isConnected = true;
    setupEventListeners();

    console.log(`MongoDB Connected: ${conn.connection.host}`);
    return conn;
  } catch (error) {
    isConnected = false;
    console.error('Lỗi kết nối MongoDB:', error.message);
    throw error;
  }
};

// Hàm Disconnect
export const disconnectDB = async () => {
  try {
    await mongoose.disconnect();
    isConnected = false;
    console.log('Đã ngắt kết nối MongoDB');
  } catch (error) {
    console.error('Lỗi ngắt kết nối:', error.message);
  }
};
