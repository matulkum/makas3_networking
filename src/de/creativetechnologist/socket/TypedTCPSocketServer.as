/**
 * Created by mak on 20.08.14.
 */
package de.creativetechnologist.socket {
import flash.events.Event;
import flash.events.ServerSocketConnectEvent;
import flash.events.TimerEvent;
import flash.net.ServerSocket;
import flash.utils.ByteArray;
import flash.utils.Dictionary;
import flash.utils.Timer;

import org.osflash.signals.Signal;

public class TypedTCPSocketServer implements ITypedTCPSocket {

	private var localPort: int;

	private var serverSocket: ServerSocket;
	private var _clientSockets: Vector.<TypedTCPSocket>;

	private var globalListeners: Vector.<Function>;
	private var type_2_listenerVector: Dictionary;

	private var retryOnErrorTimer: Timer;
	private var retryOnErrorDelay: Number = 3000;


	// (this, Boolean)
	public var signalListening: Signal;
	// (this, socket:typedTCPSocket)
	public var signalClientSocketConnect: Signal;


	//////////////////////////////
	// Getter / Setter
	//////////////////////////////
	public function get clientSockets(): Vector.<TypedTCPSocket> {
		return _clientSockets;
	}

	//////////////////////////////
	// Functions
	//////////////////////////////

	public function TypedTCPSocketServer() {
		_clientSockets = new <TypedTCPSocket>[];
		signalListening = new Signal(TypedTCPSocketServer, Boolean);
		signalClientSocketConnect = new Signal(TypedTCPSocketServer, TypedTCPSocket);
	}


	//////////////////////////////
	// Disposing
	//////////////////////////////

	public function dispose(): void {
		disposeClients();
		disposeServerSocket();
		type_2_listenerVector = null;
		globalListeners.length = 0;

		disposeRetryOnErrorTimer();
	}


	public function disposeRetryOnErrorTimer(): void {
		if (retryOnErrorTimer) {
			retryOnErrorTimer.stop();
			retryOnErrorTimer.reset();
			retryOnErrorTimer.removeEventListener(TimerEvent.TIMER_COMPLETE, onRetryOnErrorTimer);
			retryOnErrorTimer = null;
		}
	}


	protected function disposeClients(): void {
		if( _clientSockets ) {
			for each (var socket: TypedTCPSocket in _clientSockets) {
				socket.dispose();
			}
			_clientSockets.length = 0;
		}
	}

	private function disposeServerSocket(): void {
		if (serverSocket) {
			try {serverSocket.close();}
			catch (e: Error) {}
			serverSocket.removeEventListener(ServerSocketConnectEvent.CONNECT, onServerSocketConnect);
			serverSocket = null;
		}
	}


	//////////////////////////////
	// Sending
	//////////////////////////////

	public function sendInt(value: int, type: uint = 0): void {
		var i: int;
		var length: int = _clientSockets.length;
		for (i = 0; i < length; i++) {
			_clientSockets[i].sendInt(value, type);
		}
	}
	public function sendString(string: String, type: uint = 0): void {
		var i: int;
		var length: int = _clientSockets.length;
		for (i = 0; i < length; i++) {
			_clientSockets[i].sendString(string, type);
		}
	}
	public function sendObject(data: Object, type: uint = 0): void {
		var i: int;
		var length: int = _clientSockets.length;
		for (i = 0; i < length; i++) {
			_clientSockets[i].sendObject(data, type);
		}
	}
	public function sendBytes(bytes: ByteArray, type: uint = 0): void {
		var i: int;
		var length: int = _clientSockets.length;
		for (i = 0; i < length; i++) {
			_clientSockets[i].sendBytes(bytes, type);
		}
	}



	public function sendType(type: uint): void {
		var i: int;
		var length: int = _clientSockets.length;
		for (i = 0; i < length; i++) {
			_clientSockets[i].sendType(type);
		}
	}


	//////////////////////////////
	// Listeners
	//////////////////////////////

	public function addGlobalListener(listener: Function): void {
		if( !globalListeners )
			globalListeners = new <Function>[listener];
		else
			globalListeners.push(listener);

		var i: int;
		var length: int = _clientSockets.length;
		for (i = 0; i < length; i++) {
			_clientSockets[i].signalDataReceiveComplete.add(listener);
		}
	}

	public function removeGlobalListener(listener: Function): void {

		if( globalListeners ) {
			var index: int = globalListeners.indexOf(listener);
			if( index >= -1)
				globalListeners.splice(index, 1);
		}

		var i: int;
		var length: int = _clientSockets.length;
		for (i = 0; i < length; i++) {
			_clientSockets[i].signalDataReceiveComplete.remove(listener);
		}
	}


	public function addListenerForType(type: uint, listener: Function): void {
		if( !type_2_listenerVector ) {
			type_2_listenerVector = new Dictionary();
			type_2_listenerVector[type] = new <Function>[listener];
			return;
		}
		var listenerVector: Vector.<Function> = type_2_listenerVector[type];
		if( !listenerVector )
			type_2_listenerVector[type] = new <Function>[listener];

		var i: int;
		var length: int = _clientSockets.length;
		for (i = 0; i < length; i++) {
			_clientSockets[i].addListenerForType(type, listener);
		}
	}


	public function removeListenerForType(type: uint, listener: Function): void {
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
				var length: int = _clientSockets.length;
				for (i = 0; i < length; i++) {
					_clientSockets[i].removeListenerForType(type, listener);
				}
			}
		}
	}


	//////////////////////////////
	// Listening
	//////////////////////////////

	public function listen(localPort: int, retryOnError: Boolean = false): void {
		this.localPort = localPort;

//		Log.info('SignalSocketServer -> init()');

		disposeServerSocket();
		if( !retryOnError )
			disposeRetryOnErrorTimer();

		if( serverSocket )
			disposeServerSocket();

		serverSocket = new ServerSocket();

		try {
			serverSocket.bind(localPort);
			serverSocket.listen();
			serverSocket.addEventListener(ServerSocketConnectEvent.CONNECT, onServerSocketConnect);
			signalListening.dispatch(this, true);
		}
		catch(e: Error) {
			trace("SignalServerSocket->init() ::", e.toString() );
			signalListening.dispatch(this, false);
			if( retryOnError ) {
				if( !retryOnErrorTimer ) {
					retryOnErrorTimer = new Timer(retryOnErrorDelay, 1);
					retryOnErrorTimer.addEventListener(TimerEvent.TIMER_COMPLETE, onRetryOnErrorTimer);
				}
				else
					retryOnErrorTimer.reset();
				retryOnErrorTimer.start();
			}
		}
	}



	//////////////////////////////
	// Privates
	//////////////////////////////


	private function onRetryOnErrorTimer(event: TimerEvent): void {
		listen(localPort, true);
	}

	private function removeClientSocket(typedTCPSocket: TypedTCPSocket): void {
		var index: int = _clientSockets.indexOf(typedTCPSocket);
		if( index > -1) {
			_clientSockets.splice(index, 1);
			typedTCPSocket.signalConnection.remove(ontypedTCPSocketConnection);
//			typedTCPSocket.signalDataReceiveComplete.remove(ontypedTCPSocketDataReceived);
		}
		typedTCPSocket.dispose();
	}


	private function onServerSocketConnect(event: ServerSocketConnectEvent): void {

		var typedTCPSocket: TypedTCPSocket = new TypedTCPSocket(event.socket);
		typedTCPSocket.signalConnection.add(ontypedTCPSocketConnection);

		_clientSockets.push(typedTCPSocket);

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

	public function get remotePort(): int {
		return localPort;
	}

	public function get connected(): Boolean {
		if( !serverSocket )
			return false;
		return serverSocket.bound;
	}

	// TODO implement close()
	public function close(): void {
		trace('not implemented yet!');
	}


}
}
