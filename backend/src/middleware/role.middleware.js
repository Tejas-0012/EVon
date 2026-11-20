/**
 * Restrict access to specified roles
 * @param  {...string} roles - e.g. 'super_admin', 'station_admin', 'user'
 */
const restrictTo = (...roles) => {
  return (req, res, next) => {
    if (!req.user || !roles.includes(req.user.role)) {
      return res.status(403).json({
        success: false,
        message: `Forbidden: Access restricted to [${roles.join(', ')}]`,
      });
    }
    next();
  };
};

module.exports = { restrictTo };
