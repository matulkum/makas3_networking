/**
 * Created by mak on 17.02.15.
 */
package de.creativetechnologist.modem {
import flash.events.SampleDataEvent;
import flash.media.Sound;

public class AudioJackSender {

	private const SAMPLE_RATE:Number = 22050;   // Actual microphone sample rate (Hz)
	private const LOGN:uint = 11;               // Log2 FFT length
	private const N:uint = 1 << LOGN;         // FFT Length

	private var m_freq: Vector.<Number>;

	private var addedFrequencyIndizes: Vector.<int>;

	private var sound: Sound;
	private var position:int = 0;


	public function AudioJackSender() {
		var i:uint;
		m_freq = new Vector.<Number>(N/2);
		for ( i = 0; i < N/2; i++ ) {
			m_freq[i] = i*SAMPLE_RATE/N;
//			trace(i, m_freq[i]);
		}

		addedFrequencyIndizes = new <int>[];
	}


	public function dispose(): void {
		if( sound ) {
			sound.removeEventListener(SampleDataEvent.SAMPLE_DATA, onSampleData);
			sound = null;
		}
	}


	public function addFreqIndex(index: uint): void {
		if( addedFrequencyIndizes.indexOf(index) <= -1) {
			addedFrequencyIndizes.push(index);
			if( addedFrequencyIndizes.length == 1)
				play();
//			stop();
//			play();
		}
	}

	public function removeFreqIndex(index: uint): void {
		var vectorIndex: int = addedFrequencyIndizes.indexOf(index);
		if( vectorIndex > -1) {
			addedFrequencyIndizes.splice(vectorIndex, 1);
//			stop();
//			if( addedFrequencyIndizes.length > 0 )
//				play();
			if( addedFrequencyIndizes.length== 0 )
				stop();
		}

	}


	private var isPlaying: Boolean;
	
	private function play(): void {
		if( isPlaying )
			return;

		isPlaying = true;

		position = 0;
		if( !sound )
			sound = new Sound();

		sound.addEventListener(SampleDataEvent.SAMPLE_DATA, onSampleData);
		sound.play();
	}


	private function stop(): void {
		trace("AudioJackSender->stop() :: " );
		if( !isPlaying )
			return;

		isPlaying = false;
		if( sound ) {
			sound.removeEventListener(SampleDataEvent.SAMPLE_DATA, onSampleData);
			sound = null;
		}
		position = 0;
	}

	function onSampleData(event:SampleDataEvent):void
	{
		var i: int;
		var j: int;
		var length: int = addedFrequencyIndizes.length;
		for(i = 0; i < 2048; i++)
		{
			var phase:Number = position / 44100 * Math.PI * 2;
			position ++;
			var sample: Number = 0.0;
			for(j = 0; j < length; j++) {
				sample += ( Math.sin(phase * m_freq[addedFrequencyIndizes[j]]) ) / length;
			}
			event.data.writeFloat(sample);
			event.data.writeFloat(sample);
		}
	}
}
}
