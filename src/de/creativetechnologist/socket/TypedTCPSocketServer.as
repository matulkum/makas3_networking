/**
 * Created by mak on 20.08.14.
 */
package de.creativetechnologist.socket {
import flash.events.ServerSocketConnectEvent;
import flash.net.ServerSocket;
import flash.utils.Dictionary;

import org.osflash.signals.Signal;

public class TypedTCPSocketServer {

	private var localPort: int;

	private var serverSocket: ServerSocket;
	private var clientSockets: Vector.<TypedTCPSocket>;

	private var globalListeners: Vector.<Function>;
	private var type_2_listenerVector: Dictionary;

	// (this, socket:typedTCPSocket)
	public var signalClientSocketConnect: Signal;




	public function TypedTCPSocketServer() {
		clientSockets = new <TypedTCPSocket>[];
		signalClientSocketConnect = new Signal(TypedTCPSocketServer, TypedTCPSocket);
	}


	// disposing

	public function dispose(): void {
		disposeClients();
		disposeServerSocket();
		type_2_listenerVector = null;
		globalListeners.length = 0;
	}


	protected function disposeClients(): void {
		if( clientSockets ) {
			for each (var socket: TypedTCPSocket in clientSockets) {
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


	// sending

	public function sendIntToAll(value: int, type: uint = 0): void {
		var i: int;
		var length: int = clientSockets.length;
		for (i = 0; i < length; i++) {
			clientSockets[i].sendInt(value, type);
		}
	}
	public function sendStringToAll(string: String, type: uint = 0): void {
		var i: int;
		var length: int = clientSockets.length;
		for (i = 0; i < length; i++) {
			clientSockets[i].sendString(string, type);
		}
	}
	public function sendObjectToAll(data: Object, type: uint = 0): void {
		var i: int;
		var length: int = clientSockets.length;
		for (i = 0; i < length; i++) {
			clientSockets[i].sendObject(data, type);
		}
	}


	public function sendType(type: uint): void {
		var i: int;
		var length: int = clientSockets.length;
		for (i = 0; i < length; i++) {
			clientSockets[i].sendType(type);
		}
	}


	// listeners

	public function addGlobalListener(listener: Function): void {
		if( !globalListeners )
			globalListeners = new <Function>[listener];
		else
			globalListeners.push(listener);

		var i: int;
		var length: int = clientSockets.length;
		for (i = 0; i < length; i++) {
			clientSockets[i].signalDataReceiveComplete.add(listener);
		}
	}

	public function removeGlobalListener(listener: Function): void {

		if( globalListeners ) {
			var index: int = globalListeners.indexOf(listener);
			if( index >= -1)
				globalListeners.splice(index, 1);
		}

		var i: int;
		var length: int = clientSockets.length;
		for (i = 0; i < length; i++) {
			clientSockets[i].signalDataReceiveComplete.remove(listener);
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


	// start listening

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


	// privates

	private function removeClientSocket(typedTCPSocket: TypedTCPSocket): void {
		var index: int = clientSockets.indexOf(typedTCPSocket);
		if( index > -1) {
			clientSockets.splice(index, 1);
			typedTCPSocket.signalConnection.remove(ontypedTCPSocketConnection);
//			typedTCPSocket.signalDataReceiveComplete.remove(ontypedTCPSocketDataReceived);
		}
		typedTCPSocket.dispose();
	}


	private function onServerSocketConnect(event: ServerSocketConnectEvent): void {
		var typedTCPSocket: TypedTCPSocket = new TypedTCPSocket(event.socket);
		typedTCPSocket.signalConnection.add(ontypedTCPSocketConnection);

		clientSockets.push(typedTCPSocket);

		// adding global listerners
		if( globalListeners ) {
			for each( var listener: Function in globalListeners)
				typedTCPSocket.signalDataReceiveComplete.add(listener);
		}

		// adding typed listerners
		if( type_2_listenerVector ) {
			for(var type: uint in type_2_listenerVector) {
				var listenerVector: Vector.<Function> = type_2_listenerVector[type];
				if( listenerVector ) {
					for each (var listener: Function in listenerVector) {
						typedTCPSocket.addListenerForType(type, listener);
					}
				}
			}
		}
		signalClientSocketConnect.dispatch(this, typedTCPSocket);
	}


	private function ontypedTCPSocketConnection(target: TypedTCPSocket, eventType: String): void {
		if( eventType == TypedTCPSocket.EVENT_CLOSED ) {
			removeClientSocket(target);
		}
		if( eventType == TypedTCPSocket.EVENT_IOERROR ) {
			trace("SignalServerSocket->ontypedTCPSocketConnection() :: IOError" );
		}
	}
}
}
