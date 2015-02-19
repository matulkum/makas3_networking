/**
 * Created by mak on 19.02.15.
 */
package de.creativetechnologist.modem {
import flash.events.TimerEvent;
import flash.utils.Timer;

import org.osflash.signals.Signal;

public class AudioFrequencySignal extends Signal {

	public var freqIndex: int;
	private var _isOn: Boolean;

	private var idleTimer: Timer;


	public function AudioFrequencySignal(freqIndex: int, idleTimerDelay: int = 1000) {
		this.freqIndex = freqIndex;
		// (freqIndex, isOn)
		super(int, Boolean);

		if( idleTimerDelay > 0 ) {
			idleTimer = new Timer(idleTimerDelay, 1);
			idleTimer.addEventListener(TimerEvent.TIMER_COMPLETE, onIdleTimerComplete);
		}
	}


	public function dispose(): void {
		removeAll();
		if( idleTimer ) {
			idleTimer.removeEventListener(TimerEvent.TIMER_COMPLETE, onIdleTimerComplete);
			idleTimer.reset();
		}
	}


	public function get isOn(): Boolean {return _isOn;}

	public function set isOn(value: Boolean): void {
		if( idleTimer ) {
			idleTimer.reset();
			if( value )
				idleTimer.start();
		}

		if( value == _isOn )
			return;

		_isOn = value;
		dispatch(freqIndex, value);
	}


	private function onIdleTimerComplete(event: TimerEvent): void {
		isOn = false;
	}
}
}
