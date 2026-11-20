const path = require('path');
const express = require('express');
const cors = require('cors');
const morgan = require('morgan');
const dotenv = require('dotenv');

// Load environment variables (look in current dir or backend directory)
dotenv.config();
dotenv.config({ path: path.resolve(__dirname, '../.env') });

const connectDB = require('./config/db');
const apiRoutes = require('./routes/index');
const { notFound, errorHandler } = require('./middleware/error.middleware');

const app = express();

// Connect to MongoDB & ensure admin accounts exist
connectDB().then((conn) => {
  if (conn) {
    const ensureAdmins = require('./seed/ensureAdmins');
    ensureAdmins().catch((e) => console.warn('[Seed Notice]', e.message));
  }
});

// Global Middlewares
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
if (process.env.NODE_ENV !== 'test') {
  app.use(morgan('dev'));
}

// Health Check & Root API Info
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    app: 'EVon Smart EV Charging Management System (Node.js/Express Backend)',
    timestamp: new Date().toISOString(),
  });
});

app.get('/', (req, res) => {
  res.json({
    name: 'EVon API Server',
    version: '1.0.0',
    documentation: '/api/docs',
    endpoints: {
      auth: '/api/auth',
      stations: '/api/stations',
      slots: '/api/slots',
      bookings: '/api/bookings',
      payments: '/api/payments',
      recommendations: '/api/recommendations',
      ml: '/api/ml',
      analytics: '/api/analytics',
      iot: '/api/iot',
    },
  });
});

// Mount Main API Router
app.use('/api', apiRoutes);

// Error Handling Middlewares
app.use(notFound);
app.use(errorHandler);

const PORT = process.env.PORT || 5000;

if (process.env.NODE_ENV !== 'test') {
  app.listen(PORT, '0.0.0.0', () => {
    console.log(`====================================================`);
    console.log(`  ⚡ EVon Node.js API Server running on port ${PORT}`);
    console.log(`  🌐 Environment: ${process.env.NODE_ENV || 'development'}`);
    console.log(`  🔌 Health Check: /health`);
    console.log(`====================================================`);
  });
}

module.exports = app;
