/**
 * Created by mak on 21.08.14.
 */
package de.creativetechnologist.socket {


import flash.events.Event;
import flash.events.IOErrorEvent;
import flash.events.ProgressEvent;
import flash.events.TimerEvent;
import flash.net.Socket;
import flash.utils.ByteArray;
import flash.utils.Dictionary;
import flash.utils.Timer;

import org.osflash.signals.Signal;

public class TypedDataSocket {

	public var reconnectTimerDelay: Number = 4000;

	private var socket: Socket;

	private var _remotePort: int;
	public function get remotePort(): int {return _remotePort;}

	private var _remoteHost: String;
	public function get remoteHost(): String{ return _remoteHost ;}

	private var keepAlive: Boolean;

	private var retryTimer: Timer;

	private var isInit: Boolean;

	private var receivingMessageLength: uint = 0;
	private var receivingMessageFormat: int = 0;
	private var receivingMessageType: int = 0;

	// [String] => Signal(this, data:*)
	private var type_to_signal: Dictionary;
	// [String] => Signal(this, ratio:Number)
	private var type_to_progressSignal: Dictionary;

	//TODO create getter
	// (this, type: String)
	public var signalConnection: Signal;

	// (this, type:String, ratio:Number)
	public var signalDataReceiveProgress: Signal;

	// (this, data:Object, format:uint, type:String)
	public var signalDataReceiveComplete: Signal;

	public static const EVENT_CONNECTED: String = "EVENT_CONNECTED";
	public static const EVENT_CLOSED: String = "EVENT_CLOSED";
	public static const EVENT_IOERROR: String = "EVENT_IOERROR";

	public static const FORMAT_BYTES : uint = 1;
	public static const FORMAT_STRING : uint = 2;
	public static const FORMAT_INT : uint = 3;
	public static const FORMAT_OBJECT : uint = 1000;


	public function TypedDataSocket(socket: Socket = null) {
		this.socket = socket;
		signalConnection = new Signal(TypedDataSocket, String);

		// target, data, format, type
		signalDataReceiveComplete = new Signal(TypedDataSocket, Object, uint, uint);

		// target, ratio, format, type
		signalDataReceiveProgress = new Signal(TypedDataSocket, Number, uint, uint);

		if( socket )
			addSocketListener();
	}


	public function dispose(): void {
		if( socket ) {
			removeSocketListeners();
			try {
				socket.close();
			}
			catch(e: Error) {}
			socket = null;
		}

		var type: String;
		if( type_to_signal ) {
			for( type in type_to_signal ) {
				Signal(type_to_signal[type]).removeAll();
				delete type_to_signal[type];
				type_to_signal = null;
			}
		}
		if( type_to_progressSignal ) {
			for( type in type_to_progressSignal ) {
				Signal(type_to_progressSignal[type]).removeAll();
				delete type_to_progressSignal[type];
				type_to_progressSignal = null;
			}
		}

		if( retryTimer ) {
			retryTimer.stop();
			retryTimer.removeEventListener(TimerEvent.TIMER, onRetryTimer);
			keepAlive = false;
		}
	}


	public function get connected(): Boolean {
		if( !socket )
			return false;
		return socket.connected;
	}


	public function connect(remoteHost: String, remotePort: int, keepAlive: Boolean = true): Boolean {
//		Log.debug('SignalSenderSocket -> init()', remoteHost, remotePort);

		this.keepAlive = keepAlive;
		if( keepAlive ) {
			if( !retryTimer ) {
				retryTimer = new Timer(reconnectTimerDelay, 1);
				retryTimer.addEventListener(TimerEvent.TIMER, onRetryTimer);
			}
			else {
				retryTimer.reset();
			}
		}
		retryTimer.start();

		if(socket) {
			if( socket.connected )
				socket.close();
			removeSocketListeners();
			socket = null;
		}

		this._remoteHost = remoteHost;
		this._remotePort = remotePort;

		try {
			socket = new Socket();
			addSocketListener();
			socket.connect(remoteHost, remotePort);
		}
		catch (e: Error) {
			trace(e.toString());
			return false;
		}

		isInit = true;
		return true;
	}


	public function sendObject(data: Object, type: uint = 0): void {
		if( !socket || !socket.connected) {
			trace("TypedDataSocket->sendObject() :: Socket not connected" );
			return;
		}
		var bytes: ByteArray = new ByteArray();
		bytes.writeObject(data);
		bytes.position = 0;
		sendBytes(FORMAT_OBJECT, bytes, type);
	}


	public function sendInt(value: int, type: uint = 0): void {
		if( !socket || !socket.connected) {
			trace("TypedDataSocket->sendInt() :: Socket not connected" );
			return;
		}
		var bytes: ByteArray = new ByteArray();
		bytes.writeInt(value);
		bytes.position = 0;
		sendBytes(FORMAT_INT, bytes, type);

	}


	public function sendString(string: String, type: uint = 0): void {
		if( !socket || !socket.connected) {
			trace("TypedDataSocket->sendString() :: Socket not connected" );
			return;
		}
		var bytes: ByteArray = new ByteArray();
		bytes.writeUTF(string);
		bytes.position = 0;
		sendBytes(FORMAT_STRING, bytes, type);

	}


	public function sendBytes(format: uint, data: ByteArray, type: uint = 0): void {
		var sendData: ByteArray = new ByteArray();
		sendData.writeUnsignedInt(data.length);
		sendData.writeUnsignedInt(format);
		sendData.writeUnsignedInt(type);
		data.position = 0;
		sendData.writeBytes(data);

		sendData.position = 0;
		socket.writeBytes(sendData);
		socket.flush();
	}



	public function addListenerForType(type: uint, listener: Function): void {
		if( !type_to_signal )
			type_to_signal = new Dictionary();
		addListenerForTypeToSignalMap(type_to_signal, type, listener);
	}


	public function addProgressListenerForType(type: uint, listener: Function): void {
		if( !type_to_progressSignal )
			type_to_progressSignal = new Dictionary();
		addListenerForTypeToSignalMap(type_to_progressSignal, type, listener);
	}

	public function removeProgressListenerForType(type: uint, listener: Function): void {
		if( !type_to_progressSignal )
			return;
		removeListenerForType(type_to_progressSignal, type, listener);
		if( type_to_progressSignal.length <= 0)
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


	private function removeListenerForType(signalMap: Dictionary, type:uint, listener: Function): void {
		var signal: Signal = signalMap[type] as Signal;
		if(signal) {
			signal.remove(listener);
			if( signal.numListeners <= 0)
				delete signalMap[type];
		}
	}



	private function addSocketListener(): void {
		socket.addEventListener(Event.CONNECT, onSocketConnect);
		socket.addEventListener(Event.CLOSE, onSocketClose);
		socket.addEventListener(ProgressEvent.SOCKET_DATA, onClientSocketData);
		socket.addEventListener(IOErrorEvent.IO_ERROR, onSocketError);
	}


	private function removeSocketListeners(): void {
		socket.removeEventListener(Event.CONNECT, onSocketConnect);
		socket.removeEventListener(Event.CLOSE, onSocketClose);
		socket.removeEventListener(ProgressEvent.SOCKET_DATA, onClientSocketData);
		socket.removeEventListener(IOErrorEvent.IO_ERROR, onSocketError);
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
		// 4 bytes for message length + 4 bytes for messageType
		while ( clientSocket.bytesAvailable >= 12 ) {
			// is it a new Message?
			if( receivingMessageLength == 0) {
				receivingMessageLength = clientSocket.readUnsignedInt();
				receivingMessageFormat = clientSocket.readUnsignedInt();
				receivingMessageType = clientSocket.readUnsignedInt();

//				Log.debug('receiving new message with type '+ receivingMessageFormat + ' and length ' + receivingMessageLength);
			}
			// is there a full message in this packet?
			if( receivingMessageLength <= clientSocket.bytesAvailable) {
//				Log.debug('received new message with type '+ receivingMessageFormat);

				var bytes: ByteArray = new ByteArray();
				var data: *;
				clientSocket.readBytes(bytes, 0, receivingMessageLength);
				bytes.position = 0;

				if( receivingMessageFormat == FORMAT_BYTES) {
					data = bytes;
				}
				else if( receivingMessageFormat == FORMAT_STRING) {
					data = bytes.readUTF();
				}
				else if( receivingMessageFormat == FORMAT_INT ) {
					data = bytes.readInt();
				}
				// is receiving type serializable?
				else if( receivingMessageFormat >= FORMAT_OBJECT ) {
					data = bytes.readObject();
				}
				else {
					data = bytes;
					trace("TypedDataSocket->onClientSocketData() [265]:: Received data with unknown format!" );
				}

				// dispatch for all
				signalDataReceiveComplete.dispatch(this, data, receivingMessageFormat, receivingMessageType);

				// dispatch for instances which listen just for a specific type
				if( type_to_signal ) {
					var signal: Signal = type_to_signal[receivingMessageType] as Signal;
					if( signal ) {
						signal.dispatch(this, data);
					}
				}

				receivingMessageLength = 0;
				receivingMessageFormat = 0;
				receivingMessageType = 0;
			}
			// is message loading in progress?
			else {
//				Log.debug('EasySocket -> onClientSocketData(): waiting for next package');
				if(receivingMessageLength > 0) {
					signalDataReceiveProgress.dispatch(this, clientSocket.bytesAvailable / receivingMessageLength, receivingMessageFormat, receivingMessageType);

					// dispatch for instances which listen just for a specific type
					if( type_to_progressSignal ) {
						var signal: Signal = type_to_progressSignal[receivingMessageType];
						if( signal)
							signal.dispatch(this, clientSocket.bytesAvailable / receivingMessageLength);
					}
				}

				break;
			}

		}

	}


	private function onSocketConnect(event: Event): void {
//		Log.info('EasySocket -> onSocketConnect()');
		if( retryTimer ) {
			retryTimer.stop();
			retryTimer.reset();
		}


		signalConnection.dispatch(this, EVENT_CONNECTED);
	}


	private function onSocketClose(event: Event): void {
//		Log.info('EasySocket -> onSocketClose()');
		signalConnection.dispatch(this, EVENT_CLOSED);
		if( keepAlive ) {
			connect(_remoteHost, _remotePort, keepAlive);
		}
	}


	private function onSocketError(event: IOErrorEvent): void {
//		Log.info('EasySocket -> onSocketError()');
		signalConnection.dispatch(this, EVENT_IOERROR);
	}

}
}
