(function(angular, app) {
  "use strict";

  app.controller("MainController",["$scope", "$http", "$window", "$timeout", function($scope, $http, $window, $timeout) {

    $scope.days_in_month = $window.gon.days_in_month;
    $scope.category_mapping = {36 : 'Events', 37:'Births', 38:'Deaths', 39:'Holidays'}
    $scope.duplicateCount = 0;
    $scope.missingCount = 0;

    $scope.missingEvents = { 36:[], 37:[], 38:[], 39:[] };
    $scope.duplicateEvents = { 36:{}, 37:{}, 38:{}, 39:{} };

    $scope.fetchEvents = function(){
      if(!$scope.month || !$scope.day || !$scope.threshold){
        alert('form not valid');
        return;
      }
      $scope.processing = true;
      $scope.duplicateCount = 0;
      $scope.missingCount = 0;
      $scope.missingEvents = { 36:[], 37:[], 38:[], 39:[] };
      $scope.duplicateEvents = { 36:{}, 37:{}, 38:{}, 39:{} };

      var month_date = $scope.month + "_" + $scope.day+".json";
      
      $http.get("/event/date/"+month_date, {params:{threshold:$scope.threshold}})
        .then(function(response){
          $scope.events = response.data;
          $scope.status = "Fetching wikipedia events...";
          $timeout($scope.pollWikiEvents,800);
        },function(response){
          alert(response.data);
        });
    };

    $scope.pollWikiEvents = function(){
      $http.get("/event/poll.json")
        .then(function(response){

          var length = response.data.events.length;
          var responseEvents = response.data.events;

          for(var i = 0; i < length; i++){
            var eventToAdd = responseEvents[i];
            if(eventToAdd.belongs_to){
              $scope.duplicateCount++;
              if(!$scope.duplicateEvents[eventToAdd.category_id][eventToAdd.belongs_to]){
                $scope.duplicateEvents[eventToAdd.category_id][eventToAdd.belongs_to] = $scope.getParentEvent(eventToAdd.category_id, eventToAdd.belongs_to);
              }
              $scope.duplicateEvents[eventToAdd.category_id][eventToAdd.belongs_to].duplicates.push(eventToAdd);
              continue;
            }
            $scope.missingCount++;
            $scope.missingEvents[eventToAdd.category_id].push(eventToAdd)
          }

          if(response.data.status === 'Done'){
            $scope.processing = false;
          }else{
            $timeout($scope.pollWikiEvents,800);
          }
        },function(response){
        });
    };

    $scope.getParentEvent = function(category_id, event_id){
      var parentEvent =  $scope.events[category_id][event_id];
      if(!parentEvent.duplicates){
        parentEvent.duplicates = [];
      }

      delete $scope.events[category_id][event_id];
      return parentEvent;
    };

    $scope.initializing = false;

  }]);
})(angular, app);

