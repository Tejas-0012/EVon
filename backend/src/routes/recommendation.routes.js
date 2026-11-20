const express = require('express');
const router = express.Router();
const { getRouteRecommendations } = require('../controllers/recommendation.controller');

router.get('/route', getRouteRecommendations);

module.exports = router;
