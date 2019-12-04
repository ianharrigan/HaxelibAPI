package haxelib.api;
import haxe.Timer;

class ProgressOutEx extends haxelib.client.Main.ProgressOut {
    private var _cb:Dynamic->Void;
    private var _type:String;
    public function new(o, currentSize, type, cb) {
        _cb = cb;
        _type = type;
        super(o, currentSize);
    }
    
    private var _lastPercent:Int = -1;
	override function report(n) {
		cur += n;
        var p = Std.int((cur * 100.0) / max);
        var message = null;
		if( max == null) {
			message = "Downloading: " + cur + " bytes";
        } else {
			message = "Downloading: " + cur + "/" + max + " (" + Std.int((cur * 100.0) / max) + "%)";
        }
        
        if (p != _lastPercent) {
            _cb({
                type: _type,
                cur: cur,
                max: max,
                message: message
            });
            _lastPercent = p;
        }
	}
    
	public override function close() {
		//super.close();
		o.close();
		var time = Timer.stamp() - start;
		var downloadedBytes = cur - startSize;
		var speed = (downloadedBytes / time) / 1024;
		time = Std.int(time * 10) / 10;
		speed = Std.int(speed * 10) / 10;
		//Sys.print("Download complete : "+downloadedBytes+" bytes in "+time+"s ("+speed+"KB/s)\n");
        _cb({
            type: _type,
            cur: null,
            max: null,
            message: "Download complete: "+downloadedBytes+" bytes in "+time+"s ("+speed+"KB/s)"
        });
	}
}