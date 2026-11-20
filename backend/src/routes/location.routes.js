const express = require('express');
const router = express.Router();
const { geocode, reverse, search } = require('../controllers/location.controller');

router.get('/geocode', geocode);
router.get('/reverse', reverse);
router.get('/search', search);

module.exports = router;
