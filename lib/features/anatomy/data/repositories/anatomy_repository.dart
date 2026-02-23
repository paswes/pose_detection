import 'package:pose_detection/features/anatomy/domain/entities/exercise_info.dart';
import 'package:pose_detection/features/anatomy/domain/entities/muscle_group.dart';
import 'package:pose_detection/features/anatomy/domain/entities/muscle_status.dart';
import 'package:pose_detection/features/anatomy/domain/repositories/i_anatomy_repository.dart';

/// In-memory anatomy repository with hardcoded German muscle data.
///
/// Status resets on app restart. For demo purposes only.
class AnatomyRepository implements IAnatomyRepository {
  final Map<String, MuscleStatus> _statusOverrides = {};

  static const List<MuscleGroup> _muscles = [
    // ── FRONT VIEW ──────────────────────────────────────────────

    MuscleGroup(
      id: 'traps',
      nameDE: 'Trapezmuskel',
      nameLatin: 'M. trapezius',
      view: BodyView.front,
      origin:
          'Protuberantia occipitalis, Lig. nuchae, Dornfortsaetze C7-Th12',
      insertion: 'Spina scapulae, Acromion, laterales Drittel der Clavicula',
      function:
          'Schulterblattfixierung, Elevation (oberer), Retraktion (mittlerer), Depression (unterer Anteil)',
      exercises: [
        ExerciseInfo(nameDE: 'Shrugs', equipment: 'Kurzhanteln'),
        ExerciseInfo(nameDE: 'Aufrechtes Rudern', equipment: 'Langhantel'),
        ExerciseInfo(nameDE: 'Face Pulls', equipment: 'Kabelzug'),
      ],
    ),

    MuscleGroup(
      id: 'shoulders',
      nameDE: 'Schultermuskel',
      nameLatin: 'M. deltoideus',
      view: BodyView.front,
      origin:
          'Schluesselbein (Pars clavicularis), Acromion (Pars acromialis), Spina scapulae (Pars spinalis)',
      insertion: 'Tuberositas deltoidea des Humerus',
      function:
          'Armhebung (Abduktion), Flexion (vorderer Anteil), Extension (hinterer Anteil)',
      exercises: [
        ExerciseInfo(nameDE: 'Schulterdruecken', equipment: 'Kurzhanteln'),
        ExerciseInfo(nameDE: 'Seitheben', equipment: 'Kurzhanteln'),
        ExerciseInfo(nameDE: 'Frontheben', equipment: 'Langhantel'),
      ],
    ),

    MuscleGroup(
      id: 'chest',
      nameDE: 'Brustmuskel',
      nameLatin: 'M. pectoralis major',
      view: BodyView.front,
      origin: 'Schluesselbein (Clavicula), Brustbein (Sternum), Rippen 2-6',
      insertion: 'Crista tuberculi majoris des Oberarmknochens (Humerus)',
      function:
          'Adduktion, Innenrotation und Flexion des Oberarms; Atemstuetze',
      exercises: [
        ExerciseInfo(nameDE: 'Bankdruecken', equipment: 'Langhantel'),
        ExerciseInfo(nameDE: 'Liegestuetze', equipment: 'Koerpergewicht'),
        ExerciseInfo(nameDE: 'Butterfly', equipment: 'Kabelzug'),
      ],
    ),

    MuscleGroup(
      id: 'biceps',
      nameDE: 'Bizeps',
      nameLatin: 'M. biceps brachii',
      view: BodyView.front,
      origin:
          'Caput longum: Tuberculum supraglenoidale; Caput breve: Proc. coracoideus',
      insertion: 'Tuberositas radii, Aponeurosis bicipitalis',
      function: 'Ellenbogenbeugung, Unterarmsupination, Schulterflexion',
      exercises: [
        ExerciseInfo(nameDE: 'Bizepscurls', equipment: 'Langhantel'),
        ExerciseInfo(nameDE: 'Hammercurls', equipment: 'Kurzhanteln'),
        ExerciseInfo(nameDE: 'Konzentrationscurls', equipment: 'Kurzhantel'),
      ],
    ),

    MuscleGroup(
      id: 'triceps',
      nameDE: 'Trizeps',
      nameLatin: 'M. triceps brachii',
      view: BodyView.front,
      origin:
          'Caput longum: Tuberculum infraglenoidale; Caput laterale/mediale: Humerus-Rueckseite',
      insertion: 'Olecranon der Ulna',
      function: 'Ellenbogenstreckung, Schulterextension (Caput longum)',
      exercises: [
        ExerciseInfo(nameDE: 'Trizepsdruecken am Kabel', equipment: 'Kabelzug'),
        ExerciseInfo(nameDE: 'Dips', equipment: 'Barren'),
        ExerciseInfo(nameDE: 'French Press', equipment: 'SZ-Stange'),
      ],
    ),

    MuscleGroup(
      id: 'forearms',
      nameDE: 'Unterarmmuskeln',
      nameLatin: 'Mm. flexores / extensores antebrachii',
      view: BodyView.front,
      origin: 'Epicondylus medialis / lateralis des Humerus',
      insertion: 'Handwurzel-, Mittelhand- und Fingerknochen',
      function: 'Handgelenkbeugung/-streckung, Fingerbeugung, Greifkraft',
      exercises: [
        ExerciseInfo(nameDE: 'Handgelenkscurls', equipment: 'Kurzhantel'),
        ExerciseInfo(nameDE: 'Farmers Walk', equipment: 'Kurzhanteln'),
        ExerciseInfo(
            nameDE: 'Unterarmbeugen Reverse', equipment: 'Langhantel'),
      ],
    ),

    MuscleGroup(
      id: 'abs',
      nameDE: 'Gerader Bauchmuskel',
      nameLatin: 'M. rectus abdominis',
      view: BodyView.front,
      origin: 'Schambein (Os pubis)',
      insertion: 'Schwertfortsatz (Proc. xiphoideus), Rippen 5-7',
      function:
          'Rumpfbeugung, Beckenaufrichtung, Bauchpresse, Atemstuetzfunktion',
      exercises: [
        ExerciseInfo(nameDE: 'Crunches', equipment: 'Koerpergewicht'),
        ExerciseInfo(nameDE: 'Beinheben haengend', equipment: 'Klimmzugstange'),
        ExerciseInfo(nameDE: 'Plank', equipment: 'Koerpergewicht'),
      ],
    ),

    MuscleGroup(
      id: 'quads',
      nameDE: 'Quadrizeps',
      nameLatin: 'M. quadriceps femoris',
      view: BodyView.front,
      origin:
          'Spina iliaca anterior inferior (Rectus), Trochanter major und Linea aspera (Vasti)',
      insertion: 'Tuberositas tibiae (ueber die Patellarsehne)',
      function: 'Kniestreckung, Hueftbeugung (Rectus femoris)',
      exercises: [
        ExerciseInfo(nameDE: 'Kniebeugen', equipment: 'Langhantel'),
        ExerciseInfo(nameDE: 'Beinpresse', equipment: 'Maschine'),
        ExerciseInfo(nameDE: 'Ausfallschritte', equipment: 'Kurzhanteln'),
      ],
    ),

    MuscleGroup(
      id: 'calves',
      nameDE: 'Wadenmuskel',
      nameLatin: 'M. gastrocnemius / M. soleus',
      view: BodyView.front,
      origin:
          'Condylus medialis/lateralis des Femur (Gastrocnemius), Fibula/Tibia (Soleus)',
      insertion: 'Tuber calcanei (ueber die Achillessehne)',
      function:
          'Plantarflexion (Fussspitze nach unten), Kniebeugung (Gastrocnemius)',
      exercises: [
        ExerciseInfo(nameDE: 'Wadenheben stehend', equipment: 'Maschine'),
        ExerciseInfo(nameDE: 'Wadenheben sitzend', equipment: 'Maschine'),
        ExerciseInfo(
            nameDE: 'Einbeiniges Wadenheben', equipment: 'Koerpergewicht'),
      ],
    ),

    // ── BACK VIEW ───────────────────────────────────────────────

    MuscleGroup(
      id: 'lats',
      nameDE: 'Breiter Rueckenmuskel',
      nameLatin: 'M. latissimus dorsi',
      view: BodyView.back,
      origin:
          'Dornfortsaetze Th7-L5, Fascia thoracolumbalis, Crista iliaca, Rippen 9-12',
      insertion: 'Crista tuberculi minoris des Humerus',
      function:
          'Adduktion, Innenrotation, Extension und Retroversion des Arms',
      exercises: [
        ExerciseInfo(nameDE: 'Klimmzuege', equipment: 'Klimmzugstange'),
        ExerciseInfo(nameDE: 'Latzug', equipment: 'Kabelzug'),
        ExerciseInfo(nameDE: 'Langhantelrudern', equipment: 'Langhantel'),
      ],
    ),

    MuscleGroup(
      id: 'lower_back',
      nameDE: 'Unterer Ruecken',
      nameLatin: 'M. erector spinae',
      view: BodyView.back,
      origin: 'Os sacrum, Crista iliaca, Dornfortsaetze der LWS',
      insertion: 'Querfortsaetze und Dornfortsaetze der Wirbelsaeule, Rippen',
      function:
          'Aufrichtung der Wirbelsaeule, Rueckwaertsneigung, Seitneigung',
      exercises: [
        ExerciseInfo(nameDE: 'Kreuzheben', equipment: 'Langhantel'),
        ExerciseInfo(nameDE: 'Hyperextensions', equipment: 'Rueckenbank'),
        ExerciseInfo(nameDE: 'Good Mornings', equipment: 'Langhantel'),
      ],
    ),

    MuscleGroup(
      id: 'glutes',
      nameDE: 'Gesaessmuskel',
      nameLatin: 'M. gluteus maximus',
      view: BodyView.back,
      origin:
          'Os ilium (Darmbein), Os sacrum (Kreuzbein), Lig. sacrotuberale',
      insertion: 'Tractus iliotibialis, Tuberositas glutea des Femur',
      function:
          'Hueftstreckung, Aussenrotation, Abduktion (oberer Anteil)',
      exercises: [
        ExerciseInfo(nameDE: 'Hip Thrusts', equipment: 'Langhantel'),
        ExerciseInfo(
            nameDE: 'Bulgarische Kniebeugen', equipment: 'Kurzhanteln'),
        ExerciseInfo(nameDE: 'Glutebruecke', equipment: 'Koerpergewicht'),
      ],
    ),

    MuscleGroup(
      id: 'hamstrings',
      nameDE: 'Beinbeuger',
      nameLatin: 'M. biceps femoris / M. semitendinosus',
      view: BodyView.back,
      origin:
          'Tuber ischiadicum (Sitzbeinhöcker), Linea aspera (Caput breve)',
      insertion:
          'Caput fibulae (Bizeps), Pes anserinus (Semitendinosus/Semimembranosus)',
      function: 'Kniebeugung, Hueftstreckung, Unterschenkelrotation',
      exercises: [
        ExerciseInfo(nameDE: 'Rumaenisches Kreuzheben', equipment: 'Langhantel'),
        ExerciseInfo(nameDE: 'Beinbeuger liegend', equipment: 'Maschine'),
        ExerciseInfo(
            nameDE: 'Nordic Hamstring Curls', equipment: 'Koerpergewicht'),
      ],
    ),
  ];

  @override
  List<MuscleGroup> getAllMuscleGroups() {
    return _muscles.map((muscle) {
      final override = _statusOverrides[muscle.id];
      if (override != null) {
        return muscle.copyWith(status: override);
      }
      return muscle;
    }).toList();
  }

  @override
  void updateMuscleStatus(String muscleId, MuscleStatus status) {
    _statusOverrides[muscleId] = status;
  }
}
