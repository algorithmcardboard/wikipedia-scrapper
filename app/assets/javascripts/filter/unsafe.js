(function(angular, app) {
  "use strict";
  app.filter('unsafe', ["$sce", function($sce) {
    return function(val) {
      return $sce.trustAsHtml(val);
    };
  }]);
})(angular, app);
