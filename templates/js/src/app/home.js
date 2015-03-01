var app = require('./index');

app.get('/', function(page, model, params, next) {
return page.render('home');
});

app.get('/about', function(page, model, params, next) {
return page.render('about');
});
