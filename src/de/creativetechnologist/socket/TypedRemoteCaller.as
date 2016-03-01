/**
 * Created by mak on 28/01/16.
 */
package de.creativetechnologist.socket {
import org.osflash.signals.Signal;

public class TypedRemoteCaller {

	private var socket: TypedTCPSocket;
	private var msTimeout: int;

	public function TypedRemoteCaller(socket: TypedTCPSocket, msTimeout: int = 3000) {
		this.socket = socket;
		this.msTimeout = msTimeout;
	}

	public function call(sendType: uint, data: * = null):TypedRemoteCall {
		return new TypedRemoteCall(socket, sendType, data, msTimeout);
	}
}
}
