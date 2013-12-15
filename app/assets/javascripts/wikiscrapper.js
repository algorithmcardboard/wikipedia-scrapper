var app = angular.module('wikiscrapper', []);

app.config(["$httpProvider", function(provider) {
  "use strict";
  provider.defaults.headers.common['X-CSRF-Token'] = $('meta[name=csrf-token]').attr('content');
}]);

