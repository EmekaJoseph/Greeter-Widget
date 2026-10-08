import 'dart:convert';

import 'package:home_widget/home_widget.dart';

import 'widget_store.dart';

/// Keep each quote under about 110 characters or it gets cut off on the widget.
const List<String> quotes = [
  'Small small, you go reach where you dey go.',

  'No be how fast you start, na how well you finish.',

  'If you no start today, tomorrow go still wait for you.',

  'Better thing no dey come easy, but e dey worth am.',

  'No fear to start small. Every big thing start somewhere.',

  'As you keep moving, you go surely move forward.',

  'No give up because e hard. Na the hard times dey build strong people.',

  'Your effort today fit become your success tomorrow.',

  'Nobody go do am for you. Stand up and make am happen.',

  'Even if na one step, keep moving.',

  'No compare your beginning with another person middle.',

  'If you believe say you fit, you don already start winning.',

  'Time no dey wait for anybody, so use your own well.',

  'No let fear stop wetin courage fit start.',

  'Every day na another chance to do better.',

  'You fit no dey see the result yet, but your effort dey count.',

  'No rush the process. Good things take time.',

  'Your future self go thank you for the work you do today.',

  'If you fall, stand up. If you fail, try again.',

  'Success no be magic. Na consistency dey make am happen.',

  'No be every delay mean say you don fail.',

  'Keep your eyes on the goal, no matter how rough the road be.',

  'One day, all these sacrifices go make sense.',

  'No allow one bad day make you forget your big dream.',

  'Your dream deserve your effort.',

  'If you fit imagine am, you fit work towards am.',

  'No wait for perfect time. Start with the time wey you get.',

  'Every little progress still be progress.',

  'Na persistence dey turn small effort into big achievement.',

  'You no need everybody to believe in you. Believe in yourself.',

  'The road fit long, but every step dey take you closer.',

  'No stop because you never reach. Continue because you don start.',

  'Wetin you practice every day go eventually become your strength.',

  'Your current situation no be your final destination.',

  'No fear failure. Fear never trying at all.',

  'If today hard, remember say tomorrow fit better.',

  'Discipline today fit give you freedom tomorrow.',

  'No underestimate wetin you fit achieve when you stay consistent.',

  'Keep working quietly. Make your results speak for you.',

  'Even when nobody dey clap for you, keep going.',

  'Your journey no need look like another person own.',

  'No let small beginnings make you doubt big dreams.',

  'When opportunity come, make sure preparation don meet am.',

  'Success na collection of small efforts wey you repeat every day.',

  'If you no give up, you still get chance to win.',

  'Make today count. Tomorrow never promised.',

  'Your hard work fit change your whole story.',

  'No dey wait for motivation. Start, and motivation go follow.',

  'The person wey keep trying go eventually pass the person wey quit.',

  'Believe in the process, trust your effort, and keep moving.',

  'One day, you go look back and thank yourself say you never give up.',
];

/// Hands the quotes to the home screen widget, which picks from them on its own.
Future<void> saveQuotesForWidget() {
  return HomeWidget.saveWidgetData<String>(
    WidgetKeys.quotes,
    jsonEncode(quotes),
  );
}
