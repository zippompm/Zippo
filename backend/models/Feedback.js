const mongoose = require('mongoose');

const feedbackSchema = new mongoose.Schema(
  {
    orderId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Order',
      required: true,
      index: true,
    },
    orderNumber: {
      type: String,
      required: true,
      trim: true,
      index: true,
    },
    customerPhone: {
      type: String,
      trim: true,
      default: '',
    },
    riderName: {
      type: String,
      trim: true,
      default: 'Rider',
    },
    riderPhone: {
      type: String,
      trim: true,
      default: '',
    },
    rating: {
      type: Number,
      required: true,
      min: 1,
      max: 5,
      default: 5,
    },
    comment: {
      type: String,
      trim: true,
      default: '',
      maxlength: 500,
    },
    orderStatus: {
      type: String,
      enum: ['DELIVERED', 'CANCELLED', 'OTHER'],
      default: 'DELIVERED',
    },
  },
  {
    timestamps: true,
  }
);

module.exports = mongoose.model('Feedback', feedbackSchema);

