/**
 * Created by mak on 21.08.14.
 */
package de.creativetechnolgist.socket {
import flash.net.Socket;

import org.osflash.signals.Signal;

public class SocketSignal {
	private var socket: Socket;
	private var signal: Signal;

	public function SocketSignal(socket: Socket) {
		this.socket = socket;
		signal = new Signal();
	}

	public function add(listener: Function): void {
		signal.add(listener);
	}

	public function addOnce(listener:Function):Function {
		return signal.addOnce(listener);
	}

	public function remove(listener:Function):Function {
	    return signal.remove(listener);
	}
	public function removeAll():void {
		signal.removeAll();
	}


}
}
