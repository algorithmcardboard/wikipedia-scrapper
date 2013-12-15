(function(angular, app) {
  "use strict";
  app.filter('convertToGeroginYear',function(){
    return function(year){
      if(year < 0){
        return year*(-1) + " BC";
      }
      return year;
    };
  });
})(angular, app);
