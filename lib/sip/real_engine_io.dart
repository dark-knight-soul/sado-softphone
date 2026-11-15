import 'call_engine.dart';
import 'sip_engine.dart';

/// Настоящий движок звонков — для телефона и компьютера.
CallEngine createRealEngine() => SipEngine();
