(function(angular, app) {
  "use strict";
  app.filter('iif', function () {
    return function(input, trueValue, falseValue) {
      return input ? trueValue : falseValue;
    };
  });
})(angular, app);
