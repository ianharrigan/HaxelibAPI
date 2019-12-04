package haxelib.api;

class HaxeLibUserInfo {
    public var username:String;
    public var name:String;
    public var email:String;
    public var projects:Array<HaxeLibInfo> = [];
    
    public function new() {
    }
}