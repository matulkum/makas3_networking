/**
 * Created by mak on 21.08.14.
 */
package de.creativetechnologist.socket {

import flash.errors.IOError;
import flash.events.Event;
import flash.events.IOErrorEvent;
import flash.events.ProgressEvent;
import flash.events.SecurityErrorEvent;
import flash.events.TimerEvent;
import flash.net.Socket;
import flash.utils.ByteArray;
import flash.utils.Dictionary;
import flash.utils.Timer;
import flash.utils.clearTimeout;
import flash.utils.getTimer;
import flash.utils.setTimeout;

import org.osflash.signals.Signal;

public class TypedTCPSocket implements ITypedTCPSocket {

	public var reconnectTimerDelay: Number = 4000;

	private var socket: Socket;

	private var _remotePort: int;
	public function get remotePort(): int {
		return _remotePort;
	}

	private var _remoteHost: String;
	public function get remoteHost(): String{ return _remoteHost ;}

	private var keepAlive: Boolean;
	private var retryTimeoutID: uint;
	private var lastConnectionAttempTime: int;

//	private var retryTimer: Timer;

	private var isInit: Boolean;

	private var receivingMessageLength: uint = 0;
	private var receivingMessageFormat: int = -1;
	private var receivingMessageType: int = -1;

	// [String] => Signal(this, data:*, type:String)
	private var type_to_signal: Dictionary;
	// [String] => Signal(this, ratio:Number, type:String)
	private var type_to_progressSignal: Dictionary;

	// (this, type: String)
	public var signalConnection: Signal;
	//TODO create getter

	// (this, type:String, ratio:Number, type:String)
	public var signalDataReceiveProgress: Signal;
	//TODO create getter

	// (this, data:Object, type:String)
	public var signalDataReceiveComplete: Signal;
	//TODO create getter

	protected var poolingTimer: Timer;
	protected var poolingData: ByteArray;

	private const RETRY_DELAY: int = 5000;

	public static const FORMAT_EMPTY : uint = 1;
	public static const FORMAT_BYTES : uint = 2;
	public static const FORMAT_STRING : uint = 3;
	public static const FORMAT_INT : int = 4;
	public static const FORMAT_UINT : uint = 5;
	public static const FORMAT_OBJECT : uint = 10;
	public static const FORMAT_POOLING : uint = 100;

	public static const EVENT_CONNECTED: String = "EVENT_CONNECTED";
	public static const EVENT_CLOSED: String = "EVENT_CLOSED";
	public static const EVENT_IOERROR: String = "EVENT_IOERROR";
	public static const EVENT_SECURITYERROR: String = 'EVENT_SECURITYERROR';
	public static const EVENT_CREATESOCKETERROR: String = 'EVENT_CREATESOCKETERROR';



	public function TypedTCPSocket(fromSocket: Socket = null) {
		signalConnection = new Signal(TypedTCPSocket, String);

		// target, data, type
		signalDataReceiveComplete = new Signal(TypedTCPSocket, Object, uint);

		// target, ratio, type
		signalDataReceiveProgress = new Signal(TypedTCPSocket, Number, uint);

		if( fromSocket ) {
			this.socket = fromSocket;
			addSocketListener(fromSocket);
		}
	}




	public function dispose(): void {
		signalConnection.removeAll();
		signalDataReceiveProgress.removeAll();
		signalDataReceiveComplete.removeAll();
		disposeSocket();

		var type: String;
		if (type_to_signal) {
			for (type in type_to_signal)
				Signal(type_to_signal[type]).removeAll();
			type_to_signal = null;
		}
		if (type_to_progressSignal) {
			for (type in type_to_progressSignal)
				Signal(type_to_progressSignal[type]).removeAll();
			type_to_progressSignal = null;
		}

//		if( retryTimer ) {
//			retryTimer.stop();
//			retryTimer.removeEventListener(TimerEvent.TIMER, onRetryTimer);
//		}
		keepAlive = false;

		if (poolingTimer) {
			poolingTimer.reset();
			poolingTimer.removeEventListener(TimerEvent.TIMER, onPoolingTimer);
			poolingTimer = null;
		}
	}


	private function disposeSocket(): void {
		close();
		if (socket) {
			removeSocketListeners(socket);
			socket = null;
		}
	}


	public function get connected(): Boolean {
		if (!socket)
			return false;
		return socket.connected;
	}


	/**
	 *
	 * @param remoteHost
	 * @param remotePort
	 * @param keepAlive If true retries connection if connection attempt fails and reconnect  on disconnect
	 * @return False if socket could not be opened
	 */
	public function connect(remoteHost: String, remotePort: int, keepAlive: Boolean = true): Boolean {
//		Log.debug('SignalSenderSocket -> init()', remoteHost, remotePort);


		receivingMessageFormat = -1;
		receivingMessageType = -1;
		receivingMessageLength = 0;

		lastConnectionAttempTime = getTimer();

//		if( keepAlive ) {
//			if( !retryTimer ) {
//				retryTimer = new Timer(reconnectTimerDelay, 1);
//				retryTimer.addEventListener(TimerEvent.TIMER, onRetryTimer);
//			}
//			else {
//				retryTimer.reset();
//			}
//		}
//		retryTimer.start();


//		disposeSocket();

		this._remoteHost = remoteHost;
		this._remotePort = remotePort;

		if( socket )
			disposeSocket();

		// disposeSocket() sets keepAlive flase, so we set it afterwards
		this.keepAlive = keepAlive;

		try {
			socket = new Socket();
			addSocketListener(socket);
		}
		catch (e: *) {
			trace(e.toString());
			onSocketError(null);
			return false;
		}

		try {
			socket.connect(remoteHost, remotePort);
		}
		catch (e: IOError) {
			trace(e.toString());
			return false;
		}

		isInit = true;
		return true;
	}


	public function close(): void {
		if (socket) {
			try {
				socket.flush();
				socket.close();
			}
			catch (e: Error) {
			}
		}
		keepAlive = false;
		clearTimeout(retryTimeoutID);
	}


	public function sendInt(value: int, type: uint = 0): void {
		if (!socket || !socket.connected) {
			trace("TypedDataSocket->sendInt() :: Socket not connected");
			return;
		}
		var bytes: ByteArray = new ByteArray();
		bytes.writeInt(value);
		bytes.position = 0;
		sendBytes(bytes, type, FORMAT_INT);

	}
	public function sendUInt(value: uint, type: uint = 0): void {
		if (!socket || !socket.connected) {
			trace("TypedDataSocket->sendInt() :: Socket not connected");
			return;
		}
		var bytes: ByteArray = new ByteArray();
		bytes.writeUnsignedInt(value);
		bytes.position = 0;
		sendBytes(bytes, type, FORMAT_UINT);

	}


	public function sendString(string: String, type: uint = 0): void {
		if (!socket || !socket.connected) {
			trace("TypedDataSocket->sendString() :: Socket not connected");
			return;
		}
		var bytes: ByteArray = new ByteArray();
		bytes.writeUTF(string);
		bytes.position = 0;
		sendBytes(bytes, type, FORMAT_STRING);
	}


	public function sendObject(data: Object, type: uint = 0): void {
		if (!socket || !socket.connected) {
			trace("TypedDataSocket->sendObject() :: Socket not connected");
			return;
		}
		var bytes: ByteArray = new ByteArray();
		bytes.writeObject(data);
		bytes.position = 0;
		sendBytes(bytes, type, FORMAT_OBJECT);
	}


	public function sendBytes(data: ByteArray, type: uint = 0, format: uint = 2): void {
		if (!socket || !socket.connected) {
			trace("TypedBytesString() :: Socket not connected");
			return;
		}
		var sendData: ByteArray = new ByteArray();
		sendData.writeUnsignedInt(format);
		sendData.writeUnsignedInt(type);
		if (format != FORMAT_EMPTY && format != FORMAT_POOLING && format != FORMAT_INT && format != FORMAT_UINT)
			sendData.writeUnsignedInt(data.length);
		data.position = 0;
		sendData.writeBytes(data);

		sendData.position = 0;
		socket.writeBytes(sendData);
		socket.flush();
	}


	public function sendType(type: uint): void {
		if (!socket || !socket.connected) {
			trace("TypedTypeString() :: Socket not connected");
			return;
		}
		var sendData: ByteArray = new ByteArray();
		sendData.writeUnsignedInt(FORMAT_EMPTY);
		sendData.writeUnsignedInt(type);

		sendData.position = 0;
		socket.writeBytes(sendData);
		socket.flush();
	}


	/**
	 * Sends an empty message (which is ignored by the receiver) in a specified interval
	 * @param ms Intervall delay in milliSeconds
	 */
	public function startPooling(ms: int = 3000): void {
		if( !poolingTimer ) {
			poolingTimer = new Timer(ms);
			poolingTimer.addEventListener(TimerEvent.TIMER, onPoolingTimer);

			poolingData = new ByteArray();
			poolingData.writeUnsignedInt(FORMAT_POOLING);
		}
		else {
			poolingTimer.reset();
			poolingTimer.delay = ms;
		}
		poolingTimer.start();
	}


	private function onPoolingTimer(event: TimerEvent): void {
		if( connected ) {
			poolingData.position = 0;
			socket.writeBytes(poolingData);
			socket.flush();
		}
	}


	public function addListenerForType(type: uint, listener: Function): void {
		if (!type_to_signal)
			type_to_signal = new Dictionary();
		addListenerForTypeToSignalMap(type_to_signal, type, listener);
	}


	public function removeListenerForType(type: uint, listener: Function): void {
		if (!type_to_signal)
			return;

		removeListenerForTypeFromSignalMap(type_to_signal, type, listener);
		if (type_to_signal.length <= 0)
			type_to_signal = null;
	}


	public function addProgressListenerForType(type: uint, listener: Function): void {
		if (!type_to_progressSignal)
			type_to_progressSignal = new Dictionary();
		addListenerForTypeToSignalMap(type_to_progressSignal, type, listener);
	}

	public function removeProgressListenerForType(type: uint, listener: Function): void {
		if (!type_to_progressSignal)
			return;
		removeListenerForTypeFromSignalMap(type_to_progressSignal, type, listener);
		if (type_to_progressSignal.length <= 0)
			type_to_progressSignal = null;
	}


	private function addListenerForTypeToSignalMap(signalMap: Dictionary, type:uint, listener: Function): void {
		var signal: Signal;
		signal = signalMap[type];
		if( !signal ) {
			signal = new Signal();
			signalMap[type] = signal;
		}
		signal.add(listener);
	}


	private function removeListenerForTypeFromSignalMap(signalMap: Dictionary, type:uint, listener: Function): void {
		var signal: Signal = signalMap[type] as Signal;
		if(signal) {
			signal.remove(listener);
			if( signal.numListeners <= 0)
				delete signalMap[type];
		}
	}



	private function addSocketListener(socket: Socket): void {
		socket.addEventListener(Event.CONNECT, onSocketConnect);
		socket.addEventListener(Event.CLOSE, onSocketClose);
		socket.addEventListener(ProgressEvent.SOCKET_DATA, onClientSocketData);
		socket.addEventListener(IOErrorEvent.IO_ERROR, onSocketError);
		socket.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onSocketError);
	}


	private function removeSocketListeners(socket: Socket): void {
		socket.removeEventListener(Event.CONNECT, onSocketConnect);
		socket.removeEventListener(Event.CLOSE, onSocketClose);
		socket.removeEventListener(ProgressEvent.SOCKET_DATA, onClientSocketData);
		socket.removeEventListener(IOErrorEvent.IO_ERROR, onSocketError);
		socket.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, onSocketError);
	}



	private function onRetryTimer(event: TimerEvent): void {
//		Log.debug('EasySocket -> onRetryTimer()');
		connect( _remoteHost, _remotePort, keepAlive);
	}



	private function onClientSocketData(event: ProgressEvent): void {
		var clientSocket: Socket = event.target as Socket;

//		if(clientSocket.bytesAvailable < 8 ) {
//			Log.debug('package to small');
//		}


		if( receivingMessageFormat < 0 ) {
			if( clientSocket.bytesAvailable < 4)
				return;

			receivingMessageFormat = clientSocket.readUnsignedInt();
			if( receivingMessageFormat == FORMAT_POOLING ) {
				receivingMessageFormat = -1;
				if( clientSocket.bytesAvailable )
					onClientSocketData(event);
				return;
			}
		}

		// FORMAT is resolved. Checking for TYPE
		if( receivingMessageType < 0 ) {

			// enough data to resolve type?
			if( clientSocket.bytesAvailable < 4)
				return;

			receivingMessageType = clientSocket.readUnsignedInt();
		}

		// if data is FORMAT_EMPTY there is nothing more to read
		if( receivingMessageFormat == FORMAT_EMPTY) {
//			trace('received empty type', receivingMessageType);
			dispatchMessage(null, receivingMessageFormat, receivingMessageType);
			receivingMessageFormat = -1;
			receivingMessageType = -1;
			if( clientSocket.bytesAvailable )
				onClientSocketData(event);
			return;
		}
		// is FORMAT_INT ?
		else if( receivingMessageFormat == FORMAT_INT) {
			if( clientSocket.bytesAvailable >= 4) {
				dispatchMessage(clientSocket.readInt(), receivingMessageFormat, receivingMessageType)
				receivingMessageFormat = -1;
				receivingMessageType = -1;
				if( clientSocket.bytesAvailable )
					onClientSocketData(event);
				return;
			}
		}
		else if( receivingMessageFormat == FORMAT_UINT) {
			dispatchMessage(clientSocket.readUnsignedInt(), receivingMessageFormat, receivingMessageType);
			receivingMessageFormat = -1;
			receivingMessageType = -1;
			if( clientSocket.bytesAvailable )
				onClientSocketData(event);
			return;
		}
		// else format is either Object or Bytes
		else {
			// do we need to read the messageLength
			if( receivingMessageLength <= 0 ) {

				// if not enough bytes available to read messageLength
				if( clientSocket.bytesAvailable < 4)
					return;
				receivingMessageLength = clientSocket.readUnsignedInt();
			}

			// if there is not enough bytes to read the full message yet
			if( receivingMessageLength > clientSocket.bytesAvailable) {

				// dispatch progress
				signalDataReceiveProgress.dispatch(this, clientSocket.bytesAvailable / receivingMessageLength, receivingMessageType);

				// dispatch for instances which listen just for a specific type
				if( type_to_progressSignal ) {
					var signal: Signal = type_to_progressSignal[receivingMessageType];
					if( signal)
						signal.dispatch(this, clientSocket.bytesAvailable / receivingMessageLength, receivingMessageType);
				}
			}
			// else a whole message is available in the clientSocket
			else {
				var bytes: ByteArray = new ByteArray();
				clientSocket.readBytes(bytes, 0, receivingMessageLength);
				bytes.position = 0;

				var data: Object;
				if( receivingMessageFormat == FORMAT_BYTES) {
					data = bytes;
				}
				else if( receivingMessageFormat == FORMAT_STRING )
					data = bytes.readUTF();
				else
					data = bytes.readObject();

				dispatchMessage(data, receivingMessageFormat, receivingMessageType);
				receivingMessageFormat = -1;
				receivingMessageType = -1;
				receivingMessageLength = 0;
				if( clientSocket.bytesAvailable )
					onClientSocketData(event);
			}
		}
	}


	protected function dispatchMessage(data: *, format: uint, type: uint): void {
		// dispatch for all
		signalDataReceiveComplete.dispatch(this, data, type);

		// dispatch for instances which listen just for a specific type
		if( type_to_signal ) {
			var signal: Signal = type_to_signal[type] as Signal;
			if( signal ) {
				signal.dispatch(this, data, type);
			}
		}
	}


	private function onSocketConnect(event: Event): void {
		trace('EasySocket -> onSocketConnect()');
//		if( retryTimer ) {
//			retryTimer.stop();
//			retryTimer.reset();
//		}


		signalConnection.dispatch(this, EVENT_CONNECTED);
	}


	private function onSocketClose(event: Event): void {
		trace('EasySocket -> onSocketClose()');
		signalConnection.dispatch(this, EVENT_CLOSED);
		if( keepAlive ) {
			connect(_remoteHost, _remotePort, keepAlive);
		}
	}



	private function onSocketError(event: *): void {
		trace('EasySocket -> onSocketError()');
		if( event == null ) {
			signalConnection.dispatch(this, EVENT_CREATESOCKETERROR);
		}
		else if( event is IOErrorEvent)
			signalConnection.dispatch(this, EVENT_IOERROR);
		else if( event is SecurityErrorEvent)
			signalConnection.dispatch(this, EVENT_SECURITYERROR);

		if( keepAlive ) {
			var pastTime: int = getTimer() - lastConnectionAttempTime;
			if( pastTime >= RETRY_DELAY)
				connect(remoteHost, remotePort, keepAlive);
			else {
				retryTimeoutID = setTimeout(connect, RETRY_DELAY - pastTime, remoteHost, remotePort, keepAlive);
			}
		}
	}

}
}
