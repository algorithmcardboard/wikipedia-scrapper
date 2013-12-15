(function(angular, app) {
  "use strict";

  app.controller("MainController",["$scope", "$http", "$window", "$timeout", function($scope, $http, $window, $timeout) {

    $scope.days_in_month = $window.gon.days_in_month;
    $scope.category_mapping = {36 : 'Events', 37:'Births', 38:'Deaths', 39:'Holidays'}

    $scope.fetchEvents = function(){
      if(!$scope.month || !$scope.day || !$scope.threshold){
        console.lof('form not valid');
      }
      $scope.processing = true;

      var month_date = $scope.month + "_" + $scope.day+".json";
      
      $http.get("/event/date/"+month_date, {params:{threshold:$scope.threshold}})
        .then(function(response){
          $scope.events = response.data;
          $scope.status = "Fetching wikipedia events...";
          $timeout($scope.pollWikiEvents,800);
        },function(response){
        });
    };

    $scope.pollWikiEvents = function(){
      $http.get("/event/poll.json")
        .then(function(response){
          $scope.status = response.data.status;
          var length = response.data.events.length;
          var events = response.data.events;
          for(var i = 0; i < length; i++){
            var event = events[i];
            if(!event.belongs_to){
              $scope.events[event.category_id][event.event_id] = event;
              continue;
            }
            var parent_event = $scope.events[event.category_id][event.belongs_to];
            if(!parent_event.duplicates){
              parent_event.duplicates = [];
            }
            parent_event.duplicates.push(event);
          }

          $scope.status = 'Merged duplicates';

          if(response.data.status !== 'Done'){
            $timeout($scope.pollWikiEvents,800);
          }else{
            $scope.processing = false;
          }

        },function(response){
        });
    };

    $scope.initializing = false;

  }]);
})(angular, app);

