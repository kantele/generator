var app = require('../app');

module.exports = function(err, req, res, next) {
  var message, model, page, status;
  if (!err) {
    return next();
  }
  model = req.getModel();
  status = parseInt(err.status || err.message || err.toString());
  message = err.message || err.toString();
  page = app.createPage(req, res, next);
  model.set('_page.status', status);
  model.set('_page.msg', err.message || err);
  model.set('_page.url', req.url);
  if (status === 403 || status === 404 || status === 500) {
    return page.render("error:" + status);
  } else {
    return page.render("error");
  }
};
