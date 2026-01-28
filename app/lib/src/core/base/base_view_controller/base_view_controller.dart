import 'package:rxdart/rxdart.dart';

abstract class BaseViewController<T> {
  BaseViewController({required T initialData}) {
    _data = initialData;
    init();
  }
  final BehaviorSubject<T> _subject = BehaviorSubject();
  late T _data;

  void init();

  BehaviorSubject<T> get subject => _subject;

  set data(T value) => _data = value;

  void dispose() {
    _subject.close();
  }

  void notifyListener() {
    if (_subject.isClosed) {
      return;
    }
    _subject.add(_data);
  }
}
