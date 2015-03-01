  module.exports = function(expressApp) {
    return expressApp.all('*', function(req, res, next) {
      return next('404: ' + req.url);
    });
  };
