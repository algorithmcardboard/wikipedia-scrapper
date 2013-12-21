(function(angular, app) {
  "use strict";

  app.controller("MainController",["$scope", "$http", "$window", "$timeout", "$location", function($scope, $http, $window, $timeout, $location) {

    $scope.days_in_month = $window.gon.days_in_month;
    $scope.category_mapping = {36 : 'Events', 37:'Births', 38:'Deaths', 39:'Holidays'}
    $scope.duplicateCount = {36:0, 37:0, 38:0, 39:0};
    $scope.curMissingCategory = 36;
    $scope.curDuplicateCategory = 36;
    $scope.status = "Awaiting user input...";

    $scope.missingEvents = { 36:[], 37:[], 38:[], 39:[] };
    $scope.duplicateEvents = { 36:{}, 37:{}, 38:{}, 39:{} };

    $scope.setMissingCategory = function(category_id){
      $scope.curMissingCategory = category_id;
    };

    $scope.setDuplicateCategory = function(category_id){
      $scope.curDuplicateCategory = category_id;
    };

    $scope.fetchEvents = function(){
      if(!$scope.month || !$scope.day){
        alert('form not valid');
        return;
      }
      $scope.processing = true;
      $scope.fetched = false;
      $scope.missingEvents = { 36:[], 37:[], 38:[], 39:[] };
      $scope.duplicateEvents = { 36:{}, 37:{}, 38:{}, 39:{} };
      $scope.duplicateCount = {36:0, 37:0, 38:0, 39:0};

      $location.search('month',$scope.month);
      $location.search('day',$scope.day);
      $scope.status = "Fetching events...";

      var month_date = $scope.month + "_" + $scope.day+".json";
      
      $http.get("/event/date/"+month_date)
        .then(function(response){
          $scope.events = response.data;
          $scope.status = "Parsing wikipedia contents";
          $timeout($scope.pollWikiEvents,800);
        },function(response){
          alert(response.data.error);
        });
    };

    $scope.pollWikiEvents = function(){
      $http.get("/event/poll.json")
        .then(function(response){

          $scope.status = response.data.status;

          var length = response.data.events.length;
          var responseEvents = response.data.events;

          for(var i = 0; i < length; i++){
            var eventToAdd = responseEvents[i];
            if(eventToAdd.belongs_to){
              $scope.duplicateCount[eventToAdd.category_id]++;
              if(!$scope.duplicateEvents[eventToAdd.category_id][eventToAdd.belongs_to]){
                $scope.duplicateEvents[eventToAdd.category_id][eventToAdd.belongs_to] = $scope.getParentEvent(eventToAdd.category_id, eventToAdd.belongs_to);
              }
              $scope.duplicateEvents[eventToAdd.category_id][eventToAdd.belongs_to].duplicates.push(eventToAdd);
              continue;
            }
            $scope.missingEvents[eventToAdd.category_id].push(eventToAdd)
          }

          if(response.data.status === 'Done'){
            $scope.processing = false;
            $scope.fetched = true;
            $scope.events = null;
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

    $scope.serializeAllDuplicateEventsInCategory = function(){
      var dupEvents = [];
      var curCategoryHash = $scope.duplicateEvents[$scope.curDuplicateCategory];
      Object.keys(curCategoryHash).forEach(function(key){
        var dupLen = curCategoryHash[key].duplicates.length;
        for(var j=0; j < dupLen; j++){
          dupEvents[dupEvents.length] = [curCategoryHash[key].id, curCategoryHash[key].duplicates[j].event]
        }
      });
      return dupEvents;
    };

    $scope.addDuplicateEventsInCategory = function(eventObj){
      var dupEvents = [];
      if(eventObj){
        if(eventObj.processing){
          return;
        }
        eventObj.processing = true;
        dupEvents[dupEvents.length] = [eventObj.belongs_to, eventObj.event]
      }else{
        dupEvents = $scope.serializeAllDuplicateEventsInCategory();
      }

      $scope.fetched = false;
      $scope.processing = true;

      $http.post("/event/addLinks.json", {duplicateEvents: dupEvents})
        .then(function(response){
          if(eventObj){
            eventObj.processing = false;
          }
          $scope.fetched = true;
          $scope.processing = false;
        },function(response){
          $scope.fetched = true;
          $scope.processing = false;
        });

    };

    $scope.serializeAllMissingEventsInCategory = function(category_id){
      var missEvents = [];
      var length = $scope.missingEvents[$scope.curMissingCategory].length;
      for(var i = 0; i < length; i++){
        missEvents.push ($scope.missingEvents[$scope.curMissingCategory][i].event)
      }

      return missEvents;
    };

    $scope.addMissingEventsInCategory = function(eventObj){
      var missEvents = [];

      if(eventObj){
        if(eventObj.processing){
          return;
        }
        eventObj.processing = true;
        missEvents.push(eventObj.event);
      }else{
        missEvents = $scope.serializeAllMissingEventsInCategory($scope.curMissingCategory);
      }

      $scope.fetched = false;
      $scope.processing = true;

      $http.post("/event/addEvents.json", {missingEvents: missEvents, category_id : $scope.curMissingCategory, day:$scope.day, month: $scope.month})
        .then(function(response){
          if(!eventObj){
            $scope.missingEvents[$scope.curMissingCategory] = [];
          }else{
            eventObj.processing = false;
            var index = $scope.missingEvents[$scope.curMissingCategory].indexOf(eventObj);
            $scope.missingEvents[$scope.curMissingCategory].splice(index,1);
          }
          $scope.fetched = true;
          $scope.processing = false;
        },function(response){
          eventObj.processing = false;
          $scope.processing = false;
          $scope.fetched = true;
        });
    };

    $scope.checkLocationParams = function(){
      if($location.search() && $location.search().month && $location.search().day){
        $scope.month = $location.search().month;
        $scope.day = $location.search().day;
        $scope.fetchEvents();
      }
    };

    $scope.initializing = false;
    $scope.checkLocationParams();

  }]);
})(angular, app);

