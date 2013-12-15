(function(angular, app) {
  "use strict";
  app.directive('eatClick',function(){
    return function(scope,element,attrs){
      $(element).click(function(event){
        event.preventDefault();
      });
    };
  });
})(angular, app);
