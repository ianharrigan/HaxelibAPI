package haxelib.api;

class HaxeLibEvent {
    public static inline var OPERATION_STARTED:String = "operation.started";
    public static inline var OPERATION_PROGRESS:String = "operation.progress";
    public static inline var OPERATION_ENDED:String = "operation.ended";
    public static inline var OPERATION_ERRORED:String = "operation.errored";
    
    public var type:String;
    public var operationId:String;
    public var message:String;
    public var data:Dynamic;
    
    public var progressMax:Null<Float>;
    public var progressCurrent:Null<Float>;
    
    public var api:HaxeLibApi;
    
    public function new(type:String, operationId:String = null, message:String = null, data:Dynamic = null) {
        this.type = type;
        this.operationId = operationId;
        this.message = message;
        this.data = data;
    }
}