(function(angular, app) {
  "use strict";

  app.controller("MainController",["$scope", "$window", function($scope, $window) {

    $scope.days_in_month = $window.gon.days_in_month;

  }]);
})(angular, app);

