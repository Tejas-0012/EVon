const mongoose = require('mongoose');

const connectDB = async () => {
  try {
    const conn = await mongoose.connect(process.env.MONGODB_URI, {
      serverSelectionTimeoutMS: 5000,
    });
    console.log(`[Database] MongoDB Connected: ${conn.connection.host}/${conn.connection.name}`);
    return conn;
  } catch (error) {
    console.error(`[Database Error] Failed to connect to MongoDB: ${error.message}`);
    console.warn('[Database Notice] If running locally without a MongoDB daemon, please start mongod or update MONGODB_URI in .env with a MongoDB Atlas connection string.');
    // We don't exit process so server can still serve health check / docs if desired
    return null;
  }
};

module.exports = connectDB;
