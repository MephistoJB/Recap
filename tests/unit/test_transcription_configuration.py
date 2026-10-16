"""Exercise provider boundaries without downloading models or making API calls."""
import ast
import logging
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import Mock, AsyncMock

ROOT = Path(__file__).resolve().parents[2]
WHISPER = 'owl/services/stt/asynchronous/async_whisper/async_whisper_transcription_server.py'
DEEPGRAM = 'owl/services/stt/asynchronous/async_deepgram_transcription_service.py'


def load_class(path, class_name, namespace):
    tree = ast.parse((ROOT / path).read_text())
    node = next(n for n in tree.body if isinstance(n, ast.ClassDef) and n.name == class_name)
    exec(compile(ast.Module(body=[node], type_ignores=[]), path, 'exec'), namespace)
    return namespace[class_name]


class WhisperTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        self.whisperx = Mock()
        self.whisperx.load_model.return_value = Mock()
        self.whisperx.load_align_model.side_effect = lambda **kw: (object(), {'language': kw['language_code']})
        self.whisperx.align.return_value = {'segments': []}
        self.whisperx.assign_word_speakers.return_value = {'segments': []}
        self.logger = logging.getLogger('owl.unit.whisper')
        self.speaker = Mock()
        self.config = SimpleNamespace(model='tiny', device='cpu', compute_type='int8', batch_size=1,
                                      verification_model_source='test', verification_model_savedir='test',
                                      verification_threshold=0.1, hf_token='private-test-token')
        cls = load_class(WHISPER, 'AsyncWhisperTranscriptionServer', {
            'AsyncWhisperConfiguration': object, 'logger': self.logger,
            'whisperx': self.whisperx, 'SpeakerRecognition': self.speaker,
            'os': SimpleNamespace(path=SimpleNamespace(exists=lambda path: True)),
            'TranscriptionResponse': lambda **kw: SimpleNamespace(**kw, json=lambda: '{}'), 'WhisperUtterance': SimpleNamespace,
            'WhisperWord': SimpleNamespace,
        })
        self.server = cls.__new__(cls)
        self.server._config = self.config
        self.server._transcription_model = Mock()
        self.server._diarize_model = Mock(return_value=[])
        self.server._alignment_model = None
        self.server._alignment_metadata = None
        self.server._alignment_language = None

    async def transcribe(self, language):
        self.server._transcription_model.transcribe.return_value = {'segments': [], 'language': language}
        return await self.server._transcribe_audio('fixture.wav')

    def test_model_loading_does_not_log_secret_or_preload_english(self):
        with self.assertLogs(self.logger, level='INFO') as captured:
            models = self.server._load_models()
        self.assertNotIn(self.config.hf_token, '\n'.join(captured.output))
        self.assertEqual(len(models), 3)
        self.whisperx.load_align_model.assert_not_called()
        self.whisperx.DiarizationPipeline.assert_called_once_with(
            model_name='pyannote/speaker-diarization@2.1', use_auth_token=self.config.hf_token, device='cpu')

    async def test_german_alignment_is_selected_and_reused(self):
        await self.transcribe('de')
        first = self.server._alignment_model
        await self.transcribe('de')
        self.whisperx.load_align_model.assert_called_once_with(language_code='de', device='cpu')
        self.assertIs(self.server._alignment_model, first)
        self.assertEqual(self.whisperx.align.call_args.args[2]['language'], 'de')

    async def test_language_switch_selects_matching_alignment(self):
        await self.transcribe('de')
        await self.transcribe('en')
        self.assertEqual(self.server._alignment_language, 'en')
        self.assertEqual(self.whisperx.align.call_args.args[2]['language'], 'en')
        self.assertEqual(self.whisperx.load_align_model.call_count, 2)

    async def test_failed_language_load_does_not_mark_model_as_loaded(self):
        await self.transcribe('en')
        old_model = self.server._alignment_model
        self.whisperx.load_align_model.side_effect = RuntimeError('download unavailable')
        with self.assertRaisesRegex(RuntimeError, 'download unavailable'):
            await self.transcribe('de')
        self.assertEqual(self.server._alignment_language, 'en')
        self.assertIs(self.server._alignment_model, old_model)
        self.whisperx.load_align_model.side_effect = lambda **kw: (object(), {'language': kw['language_code']})
        await self.transcribe('de')
        self.assertEqual(self.server._alignment_language, 'de')


class DeepgramTests(unittest.IsolatedAsyncioTestCase):
    async def test_configured_language_is_passed_with_audio(self):
        options = Mock(return_value=object())
        client = Mock()
        client.listen.asyncprerecorded.v.return_value.transcribe_file = AsyncMock(return_value={'result': 'ok'})
        cls = load_class(DEEPGRAM, 'AsyncDeepgramTranscriptionService', {
            'AbstractAsyncTranscriptionService': object, 'Transcription': object, 'FileSource': dict,
            'DeepgramClient': Mock(return_value=client), 'PrerecordedOptions': options,
            'httpx': SimpleNamespace(Timeout=Mock()), 'logger': Mock(),
        })
        service = cls(SimpleNamespace(api_key='test-key', language='de', model='nova-2'))
        response = await service._transcribe_with_deepgram(b'audio')
        self.assertEqual(response, {'result': 'ok'})
        self.assertEqual(options.call_args.kwargs['language'], 'de')
        self.assertTrue(options.call_args.kwargs['diarize'])
        self.assertEqual(client.listen.asyncprerecorded.v.return_value.transcribe_file.call_args.kwargs['source'], {'buffer': b'audio'})


if __name__ == '__main__':
    unittest.main()
