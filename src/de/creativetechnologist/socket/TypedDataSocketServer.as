/**
 * Created by mak on 20.08.14.
 */
package de.creativetechnologist.socket {
import flash.events.ServerSocketConnectEvent;
import flash.net.ServerSocket;
import flash.utils.Dictionary;

import org.osflash.signals.Signal;

public class TypedDataSocketServer {

	private var localPort: int;

	private var serverSocket: ServerSocket;
	private var clientSockets: Vector.<TypedDataSocket>;

	private var type_2_listenerVector: Dictionary;

	// (this, socket:TypedDataSocket)
	public var signalClientSocketConnect: Signal;




	public function TypedDataSocketServer() {
		clientSockets = new <TypedDataSocket>[];
		signalClientSocketConnect = new Signal(TypedDataSocketServer, TypedDataSocket);
	}


	public function dispose(): void {
		disposeClients();
		disposeServerSocket();
		type_2_listenerVector = null;
	}


	protected function disposeClients(): void {
		if( clientSockets ) {
			for each (var socket: TypedDataSocket in clientSockets) {
				socket.dispose();
			}
			clientSockets.length = 0;
		}
	}

	private function disposeServerSocket(): void {
		if (serverSocket) {
			try {serverSocket.close();}
			catch (e: Error) {}
			serverSocket = null;
		}
	}



	public function addListenerForGlobalType(type: uint, listener: Function): void {
		if( !type_2_listenerVector ) {
			type_2_listenerVector = new Dictionary();
			type_2_listenerVector[type] = new <Function>[listener];
			return;
		}
		var listenerVector: Vector.<Function> = type_2_listenerVector[type];
		if( !listenerVector )
			type_2_listenerVector[type] = new <Function>[listener];

		var i: int;
		var length: int = clientSockets.length;
		for (i = 0; i < length; i++) {
			clientSockets[i].addListenerForType(type, listener);
		}
	}


	public function removeListenerForGlobalType(type: uint, listener: Function): void {
		if( !type_2_listenerVector)
			return;

		var listenerVector: Vector.<Function> = type_2_listenerVector[type];
		if( listenerVector ) {
			var index: int = listenerVector.indexOf(listener);
			if( index > -1) {
				listenerVector.splice(index, 1);
				if( listenerVector.length == 0)
					delete type_2_listenerVector[type];

				var i: int;
				var length: int = clientSockets.length;
				for (i = 0; i < length; i++) {
					clientSockets[i].removeListenerForType(type, listener);
				}
			}
		}
	}


	public function listen(localPort: int): void {

		this.localPort = localPort;

//		Log.info('SignalSocketServer -> init()');

		disposeServerSocket()
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

		if( type_2_listenerVector ) {
			for(var type: uint in type_2_listenerVector)
			var listenerVector: Vector.<Function> = type_2_listenerVector[type];
			if( listenerVector ) {
				for each (var listener: Function in listenerVector) {
					typedDataSocket.addListenerForType(type, listener);
				}
			}
		}
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
