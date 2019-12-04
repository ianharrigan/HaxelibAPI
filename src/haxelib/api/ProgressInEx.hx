package haxelib.api;

class ProgressInEx extends haxelib.client.Main.ProgressIn {
    private var _cb:Dynamic->Void;
    public function new( i, tot, cb) {
        _cb = cb;
        super(i, tot);
    }
    
    private var _lastPercent:Int = -1;
	override function report( nbytes : Int ) {
		pos += nbytes;
        var p = Std.int((pos * 100.0) / tot);
		var message = "Sending to haxelib: " + pos + "/" + tot + " (" + Std.int((pos * 100.0) / tot) + "%)";
        
        if (p != _lastPercent) {
            _cb({
                cur: pos,
                max: tot,
                message: message
            });
            _lastPercent = p;
        }
        
        if (pos >= tot) {
            _cb({
                cur: null,
                max: null,
                message: "Send complete"
            });
        }
	}
}