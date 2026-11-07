const express = require('express');
const router = express.Router();
const {
  loginAdmin,
  getDashboardStats,
  getLiveOrders,
  getRiderHistory,
  getAllRiders,
  getFeedbacks,
} = require('../controllers/adminController');

// Admin Authentication
router.post('/login', loginAdmin);

// Dashboard Statistics & Active Dispatches
router.get('/dashboard', getDashboardStats);

// Customer Post-Order Feedback Records
router.get('/feedbacks', getFeedbacks);

// Live Orders (Real-time monitoring of all active orders and their assigned riders)
router.get('/live-orders', getLiveOrders);

// Rider History (Delivered and closed orders by riders)
router.get('/rider-history', getRiderHistory);

// All Riders overview
router.get('/riders', getAllRiders);

module.exports = router;
