/**
 * Created by mak on 20.08.14.
 */
package de.creativetechnologist.socket {
import flash.events.ServerSocketConnectEvent;
import flash.net.ServerSocket;

import org.osflash.signals.Signal;

public class TypedDataSocketServer {

	private var localPort: int;

	private var serverSocket: ServerSocket;
	private var clientSockets: Vector.<TypedDataSocket>;

	// (this, socket:TypedDataSocket)
	public var signalClientSocketConnect: Signal;

	private var isInit: Boolean = false;

	public function TypedDataSocketServer() {
		signalClientSocketConnect = new Signal(TypedDataSocketServer, TypedDataSocket);
	}


	public function dispose(): void {
		if( clientSockets ) {
			for each (var socket: TypedDataSocket in clientSockets) {
				socket.dispose();
			}
			clientSockets.length = 0;
		}
	}


	public function listen(localPort: int): void {
		if( isInit )
			return;
		isInit = true;

		this.localPort = localPort;

//		Log.info('SignalSocketServer -> init()');


		clientSockets = new <TypedDataSocket>[];

		serverSocket = new ServerSocket();
		try {
			serverSocket.bind(localPort);
			serverSocket.addEventListener(ServerSocketConnectEvent.CONNECT, onServerSocketConnect);
			serverSocket.listen();
		}
		catch(e: Error) {
			trace("SignalServerSocket->init() ::", e.toString() );
		}
	}



	private function removeClientSocket(typedDataSocket: TypedDataSocket): void {
		var index: int = clientSockets.indexOf(typedDataSocket);
		if( index > -1) {
			clientSockets.splice(index, 1);
			typedDataSocket.signalConnection.remove(onTypedDataSocketConnection);
//			typedDataSocket.signalDataReceiveComplete.remove(onTypedDataSocketDataReceived);
		}
		typedDataSocket.dispose();
	}


	private function onServerSocketConnect(event: ServerSocketConnectEvent): void {
		var typedDataSocket: TypedDataSocket = new TypedDataSocket(event.socket);
		typedDataSocket.signalConnection.add(onTypedDataSocketConnection);

//		typedDataSocket.signalDataReceiveComplete.add(onTypedDataSocketDataReceived);

		clientSockets.push(typedDataSocket);
		signalClientSocketConnect.dispatch(this, typedDataSocket);
	}


	private function onTypedDataSocketConnection(target: TypedDataSocket, eventType: String): void {
		if( eventType == TypedDataSocket.EVENT_CLOSED ) {
			removeClientSocket(target);
		}
		if( eventType == TypedDataSocket.EVENT_IOERROR ) {
			trace("SignalServerSocket->onTypedDataSocketConnection() :: IOError" );
		}
	}


//	private function onTypedDataSocketDataReceived(target: TypedDataSocket, data: Object, format: uint, type: uint): void {
//	}

}
}
