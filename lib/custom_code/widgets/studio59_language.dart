// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/flutter_flow/ff_builtin_enums.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/widgets/index.dart'; // Imports other custom widgets
import '/custom_code/actions/index.dart'; // Imports custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart' hide RepeatMode;
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:flutter/material.dart';

/// Idioma do fluxo do convidado: PT por defeito, FR e EN.
final ValueNotifier<String> s59Language = ValueNotifier('pt');

/// Traduz um texto português; {n} são valores. Textos sem tradução (ex.: do servidor) ficam em português.
String s59tr(String pt, [Map<String, Object?> args = const {}]) {
  final row = s59Language.value == 'pt' ? null : _s59Texts[pt];
  var text = row == null ? pt : row[s59Language.value == 'fr' ? 0 : 1];
  args.forEach((key, value) => text = text.replaceAll('{$key}', '$value'));
  return text;
}

/// Tutorial passo a passo (botão «Ajuda», em todos os ecrãs do convidado).
Future<void> s59ShowHelp(BuildContext context) async {
  const rose = Color(0xFFB77F84);
  const steps = [
    (
      Icons.touch_app_outlined,
      'Ver uma fotografia em grande',
      'Toque numa fotografia para a abrir em ecrã inteiro. Afaste dois dedos (ou toque duas vezes) para aproximar e deslize para o lado para ver a seguinte.'
    ),
    (
      Icons.add_circle_outline,
      'Escolher fotografias',
      'Toque no sinal + por baixo da fotografia, ou em «Adicionar ao carrinho» quando ela está aberta. As escolhidas ficam com um visto.'
    ),
    (
      Icons.face_retouching_natural,
      'Encontrar as suas fotografias',
      'Toque em «Encontrar as minhas fotos» e tire uma selfie. Mostramos as fotografias onde aparece. Pode tirar a selfie com mais pessoas: mostramos as fotografias de cada uma e as que têm em conjunto.'
    ),
    (
      Icons.shopping_bag_outlined,
      'Ver o carrinho',
      'O botão «Ver carrinho», sempre visível no fundo do ecrã, mostra as fotografias escolhidas. Aí escolhe as quantidades e conclui o pedido.'
    ),
    (
      Icons.edit_note,
      'Concluir o pedido',
      'Indique a sua mesa e o seu nome e escolha como recebe as fotografias. Toque no «i» de cada opção para saber o que significa.'
    ),
    (
      Icons.receipt_long_outlined,
      'Depois do pedido',
      'Dirija-se ao fotógrafo e diga o seu nome para pagar. Depois passe o iPad à próxima pessoa da sua mesa.'
    ),
  ];
  var index = 0;
  await showDialog<void>(
      context: context,
      builder: (dialogContext) =>
          StatefulBuilder(builder: (dialogContext, update) {
            final step = steps[index];
            final last = index == steps.length - 1;
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
              contentPadding: const EdgeInsets.fromLTRB(28, 28, 28, 8),
              content: SizedBox(
                  width: 460,
                  child: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                        padding: const EdgeInsets.all(18),
                        decoration: const BoxDecoration(
                            color: Color(0xFFF6ECEC), shape: BoxShape.circle),
                        child: Icon(step.$1, color: rose, size: 52)),
                    const SizedBox(height: 18),
                    Text(s59tr(step.$2),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF292624))),
                    const SizedBox(height: 12),
                    Text(s59tr(step.$3),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 19,
                            height: 1.4,
                            color: Color(0xFF292624))),
                    const SizedBox(height: 18),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                            steps.length,
                            (i) => Container(
                                width: i == index ? 22 : 10,
                                height: 10,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 3),
                                decoration: BoxDecoration(
                                    color: i == index
                                        ? rose
                                        : const Color(0xFFE5D8D8),
                                    borderRadius: BorderRadius.circular(5))))),
                  ]))),
              actionsAlignment: MainAxisAlignment.spaceBetween,
              actions: [
                TextButton(
                    onPressed: index == 0
                        ? () => Navigator.pop(dialogContext)
                        : () => update(() => index--),
                    child: Text(s59tr(index == 0 ? 'Fechar' : 'Anterior'),
                        style: const TextStyle(
                            fontSize: 18, color: Color(0xFF6D625F)))),
                FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: rose,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 26, vertical: 16)),
                    onPressed: last
                        ? () => Navigator.pop(dialogContext)
                        : () => update(() => index++),
                    child: Text(s59tr(last ? 'Começar' : 'Seguinte'),
                        style: const TextStyle(fontSize: 18))),
              ],
            );
          }));
}

/// Escolha de idioma e botão «Ajuda»: presentes em todos os ecrãs do convidado.
class Studio59Language extends StatelessWidget {
  const Studio59Language({super.key, this.width, this.height});
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    const rose = Color(0xFFB77F84);
    return ValueListenableBuilder<String>(
        valueListenable: s59Language,
        builder: (context, lang, _) => Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                runSpacing: 8,
                children: [
                  SegmentedButton<String>(
                    showSelectedIcon: false,
                    style: SegmentedButton.styleFrom(
                        selectedBackgroundColor: const Color(0xFFF2E5E3),
                        selectedForegroundColor: const Color(0xFF292624),
                        foregroundColor: const Color(0xFF6D625F),
                        side: const BorderSide(color: rose),
                        visualDensity: VisualDensity.compact),
                    segments: const [
                      ButtonSegment(value: 'pt', label: Text('PT')),
                      ButtonSegment(value: 'fr', label: Text('FR')),
                      ButtonSegment(value: 'en', label: Text('EN'))
                    ],
                    selected: {lang},
                    onSelectionChanged: (value) =>
                        s59Language.value = value.first,
                  ),
                  OutlinedButton.icon(
                      onPressed: () => s59ShowHelp(context),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: rose,
                          side: const BorderSide(color: rose),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      icon: const Icon(Icons.help_outline, size: 18),
                      label: Text(s59tr('Ajuda'))),
                ]));
  }
}

const Map<String, List<String>> _s59Texts = {
  'Receber as fotografias digitais': [
    'Recevoir les photos numériques',
    'Receive the digital photos'
  ],
  'Para receber as fotografias digitais, insira o seu email. Enviamos-lhe o link depois do pagamento.':
      [
    'Pour recevoir les photos numériques, saisissez votre e-mail. Nous vous enverrons le lien après le paiement.',
    'To receive the digital photos, enter your email. We will send you the link after payment.'
  ],
  'Email': ['E-mail', 'Email'],
  'Voltar': ['Retour', 'Back'],
  'Continuar sem email': ['Continuer sans e-mail', 'Continue without email'],
  'Confirmar email': ['Confirmer l\'e-mail', 'Confirm email'],
  'Ajuda': ['Aide', 'Help'],
  'Fechar': ['Fermer', 'Close'],
  'Anterior': ['Précédent', 'Previous'],
  'Seguinte': ['Suivant', 'Next'],
  'Começar': ['Commencer', 'Start'],
  'Cancelar': ['Annuler', 'Cancel'],
  'Sair': ['Quitter', 'Exit'],
  'Ver uma fotografia em grande': [
    'Voir une photo en grand',
    'View a photo full size'
  ],
  'Toque numa fotografia para a abrir em ecrã inteiro. Afaste dois dedos (ou toque duas vezes) para aproximar e deslize para o lado para ver a seguinte.':
      [
    'Touchez une photo pour l\'ouvrir en plein écran. Écartez deux doigts (ou touchez deux fois) pour zoomer et faites glisser pour voir la suivante.',
    'Tap a photo to open it full screen. Spread two fingers (or double tap) to zoom and swipe sideways to see the next one.'
  ],
  'Escolher fotografias': ['Choisir des photos', 'Choose photos'],
  'Toque no sinal + por baixo da fotografia, ou em «Adicionar ao carrinho» quando ela está aberta. As escolhidas ficam com um visto.':
      [
    'Touchez le signe + sous la photo, ou « Ajouter au panier » lorsqu\'elle est ouverte. Les photos choisies sont cochées.',
    'Tap the + sign below the photo, or "Add to cart" when it is open. Chosen photos get a tick.'
  ],
  'Encontrar as suas fotografias': ['Trouver vos photos', 'Find your photos'],
  'Toque em «Encontrar as minhas fotos» e tire uma selfie. Mostramos as fotografias onde aparece. Pode tirar a selfie com mais pessoas: mostramos as fotografias de cada uma e as que têm em conjunto.':
      [
    'Touchez « Trouver mes photos » et prenez un selfie. Nous affichons les photos où vous apparaissez. Vous pouvez prendre le selfie à plusieurs : nous affichons les photos de chacun et celles où vous êtes ensemble.',
    'Tap "Find my photos" and take a selfie. We show the photos you appear in. You can take the selfie with other people: we show each person\'s photos and the ones you are in together.'
  ],
  'Ver o carrinho': ['Voir le panier', 'View the cart'],
  'O botão «Ver carrinho», sempre visível no fundo do ecrã, mostra as fotografias escolhidas. Aí escolhe as quantidades e conclui o pedido.':
      [
    'Le bouton « Voir le panier », toujours visible en bas de l\'écran, affiche les photos choisies. Vous y choisissez les quantités et finalisez la commande.',
    'The "View cart" button, always visible at the bottom of the screen, shows your chosen photos. There you choose quantities and complete the order.'
  ],
  'Concluir o pedido': ['Finaliser la commande', 'Complete the order'],
  'Indique a sua mesa e o seu nome e escolha como recebe as fotografias. Toque no «i» de cada opção para saber o que significa.':
      [
    'Indiquez votre table et votre nom et choisissez comment recevoir les photos. Touchez le « i » de chaque option pour savoir ce qu\'elle signifie.',
    'Enter your table and your name and choose how to receive the photos. Tap the "i" on each option to see what it means.'
  ],
  'Depois do pedido': ['Après la commande', 'After the order'],
  'Dirija-se ao fotógrafo e diga o seu nome para pagar. Depois passe o iPad à próxima pessoa da sua mesa.':
      [
    'Adressez-vous au photographe et donnez votre nom pour payer. Passez ensuite l\'iPad à la personne suivante de votre table.',
    'Go to the photographer and give your name to pay. Then pass the iPad to the next person at your table.'
  ],
  'Antes de continuar': ['Avant de continuer', 'Before you continue'],
  'Para encontrar as suas fotografias, a selfie é comparada com as fotografias do evento.':
      [
    'Pour trouver vos photos, le selfie est comparé aux photos de l\'événement.',
    'To find your photos, the selfie is compared with the event photos.'
  ],
  'Não guardamos os seus dados faciais: a selfie é eliminada logo após o reconhecimento.':
      [
    'Nous ne conservons pas vos données faciales : le selfie est supprimé immédiatement après la reconnaissance.',
    'We do not keep your facial data: the selfie is deleted right after recognition.'
  ],
  'Aceito e continuo': ['J\'accepte et je continue', 'Accept and continue'],
  'Encontrar as minhas fotografias': ['Trouver mes photos', 'Find my photos'],
  'Encontrar as minhas fotos': ['Trouver mes photos', 'Find my photos'],
  'A procurar…': ['Recherche…', 'Searching…'],
  'Tire uma selfie de frente, com boa luz. Pode ser com mais pessoas: mostramos as fotografias de cada uma e as que têm em conjunto.':
      [
    'Prenez un selfie de face, avec une bonne lumière. Il peut y avoir plusieurs personnes : nous affichons les photos de chacune et celles où vous êtes ensemble.',
    'Take a front-facing selfie in good light. Other people can be in it: we show each person\'s photos and the ones you are in together.'
  ],
  'Tirar selfie': ['Prendre un selfie', 'Take a selfie'],
  'Escolher uma fotografia': ['Choisir une photo', 'Choose a photo'],
  'Sair do catálogo': ['Quitter le catalogue', 'Exit the catalogue'],
  'Sair do catálogo?': ['Quitter le catalogue ?', 'Exit the catalogue?'],
  'Vai voltar ao ecrã inicial.': [
    'Vous allez revenir à l\'écran d\'accueil.',
    'You will return to the home screen.'
  ],
  'As {n} fotografias selecionadas serão removidas do carrinho.': [
    'Les {n} photos sélectionnées seront retirées du panier.',
    'The {n} selected photos will be removed from the cart.'
  ],
  '{p} € por fotografia': ['{p} € par photo', '{p} € per photo'],
  'Ver todas': ['Voir tout', 'See all'],
  'Sem fotografias encontradas para esta selfie.': [
    'Aucune photo trouvée pour ce selfie.',
    'No photos found for this selfie.'
  ],
  'Não existem fotografias disponíveis neste evento.': [
    'Aucune photo disponible pour cet événement.',
    'There are no photos available for this event.'
  ],
  'Fotografia': ['Photo', 'Photo'],
  'Adicionar ao carrinho': ['Ajouter au panier', 'Add to cart'],
  'Já está no carrinho': ['Déjà dans le panier', 'Already in the cart'],
  'Esta fotografia já está no carrinho.': [
    'Cette photo est déjà dans le panier.',
    'This photo is already in the cart.'
  ],
  'A carregar…': ['Chargement…', 'Loading…'],
  'Carregar mais fotografias': ['Charger plus de photos', 'Load more photos'],
  'Ver carrinho (vazio)': ['Voir le panier (vide)', 'View cart (empty)'],
  'Ver carrinho ({n})': ['Voir le panier ({n})', 'View cart ({n})'],
  '{a} de {b}': ['{a} sur {b}', '{a} of {b}'],
  'Afaste dois dedos para aproximar · deslize para o lado para a seguinte': [
    'Écartez deux doigts pour zoomer · faites glisser pour la suivante',
    'Spread two fingers to zoom · swipe sideways for the next one'
  ],
  'menos de 1 minuto': ['moins d\'une minute', 'less than 1 minute'],
  'cerca de 1 minuto': ['environ 1 minute', 'about 1 minute'],
  'cerca de {n} minutos': ['environ {n} minutes', 'about {n} minutes'],
  'A pesquisa por rosto não está disponível nesta sessão. Pode procurar as suas fotografias no catálogo.':
      [
    'La recherche par visage n\'est pas disponible pour cette session. Vous pouvez chercher vos photos dans le catalogue.',
    'Face search is not available in this session. You can look for your photos in the catalogue.'
  ],
  'A pesquisa por rosto fica disponível dentro de {t}. Já analisámos {a} de {b} fotografias.':
      [
    'La recherche par visage sera disponible dans {t}. Nous avons déjà analysé {a} photos sur {b}.',
    'Face search will be available in {t}. We have already analysed {a} of {b} photos.'
  ],
  'Não encontrámos fotografias suas. Tente outra selfie, de frente e com boa luz.':
      [
    'Nous n\'avons pas trouvé vos photos. Essayez un autre selfie, de face et avec une bonne lumière.',
    'We did not find your photos. Try another selfie, front-facing and in good light.'
  ],
  '{n} fotografias encontradas': ['{n} photos trouvées', '{n} photos found'],
  '1 fotografia encontrada': ['1 photo trouvée', '1 photo found'],
  '{p} pessoas na selfie: {n} fotografias, {t} em conjunto': [
    '{p} personnes sur le selfie : {n} photos, dont {t} ensemble',
    '{p} people in the selfie: {n} photos, {t} together'
  ],
  'Uma das pessoas não foi encontrada; tente uma selfie só dessa pessoa.': [
    'Une des personnes n\'a pas été trouvée ; essayez un selfie de cette personne seule.',
    'One of the people was not found; try a selfie of that person alone.'
  ],
  'Ainda estamos a analisar {n} fotografias; tente de novo daqui a pouco.': [
    'Nous analysons encore {n} photos ; réessayez dans un instant.',
    'We are still analysing {n} photos; try again shortly.'
  ],
  'A sessão do evento terminou. Volte a introduzir o PIN.': [
    'La session de l\'événement est terminée. Saisissez à nouveau le code PIN.',
    'The event session has ended. Please enter the PIN again.'
  ],
  'A pesquisa por rosto ainda não está disponível nesta ligação.': [
    'La recherche par visage n\'est pas encore disponible sur cette connexion.',
    'Face search is not yet available on this connection.'
  ],
  'Não foi possível contactar o servidor.': [
    'Impossible de contacter le serveur.',
    'Could not reach the server.'
  ],
  'Nenhum rosto detetado.': ['Aucun visage détecté.', 'No face detected.'],
  'O carrinho está vazio.': ['Le panier est vide.', 'The cart is empty.'],
  'Volte à galeria e escolha as fotografias que pretende.': [
    'Retournez à la galerie et choisissez les photos souhaitées.',
    'Go back to the gallery and choose the photos you want.'
  ],
  'Ver galeria': ['Voir la galerie', 'View gallery'],
  '{n} fotografias selecionadas': [
    '{n} photos sélectionnées',
    '{n} photos selected'
  ],
  '{m} cada': ['{m} l\'unité', '{m} each'],
  'Diminuir': ['Diminuer', 'Decrease'],
  'Aumentar': ['Augmenter', 'Increase'],
  'Remover': ['Retirer', 'Remove'],
  'Total das fotografias': ['Total des photos', 'Photos total'],
  'Adicionar mais fotografias': ['Ajouter d\'autres photos', 'Add more photos'],
  'Continuar para checkout': ['Passer à la commande', 'Continue to checkout'],
  '{a} fotografias · {b} unidades': [
    '{a} photos · {b} exemplaires',
    '{a} photos · {b} copies'
  ],
  'Os seus dados': ['Vos coordonnées', 'Your details'],
  'Todos os campos com * são obrigatórios.': [
    'Tous les champs marqués * sont obligatoires.',
    'All fields marked * are required.'
  ],
  'Qual é a sua mesa? *': [
    'Quelle est votre table ? *',
    'Which is your table? *'
  ],
  'Ex.: 12 ou Noivos': ['Ex. : 12 ou Mariés', 'E.g. 12 or Newlyweds'],
  'Nome *': ['Nom *', 'Name *'],
  'Telefone (opcional)': ['Téléphone (facultatif)', 'Phone (optional)'],
  'Email *': ['E-mail *', 'Email *'],
  'Email (opcional)': ['E-mail (facultatif)', 'Email (optional)'],
  'O email é obrigatório porque escolheu o envio para a morada.': [
    'L\'e-mail est obligatoire car vous avez choisi la livraison à domicile.',
    'Email is required because you chose delivery to an address.'
  ],
  'Se indicar o email, enviamos para lá o link das fotografias digitais.': [
    'Si vous indiquez un e-mail, nous y enverrons le lien des photos numériques.',
    'If you give an email, we will send the link to the digital photos there.'
  ],
  'Entrega': ['Livraison', 'Delivery'],
  'Noivos entregam': ['Remise par les mariés', 'Couple delivers'],
  'Levantamento': ['Retrait', 'Pick-up'],
  'Envio': ['Envoi', 'Shipping'],
  'Grátis': ['Gratuit', 'Free'],
  'Morada de envio *': ['Adresse de livraison *', 'Delivery address *'],
  'Os noivos recebem as suas fotografias impressas e entregam-lhas depois. Não tem custos.':
      [
    'Les mariés reçoivent vos photos imprimées et vous les remettent ensuite. Sans frais.',
    'The couple receive your printed photos and hand them to you later. No cost.'
  ],
  'Levanta as fotografias impressas na loja Studio 59, quando estiverem prontas. Não tem custos.':
      [
    'Vous retirez les photos imprimées au magasin Studio 59 lorsqu\'elles sont prêtes. Sans frais.',
    'You collect the printed photos from the Studio 59 shop when they are ready. No cost.'
  ],
  'Enviamos as fotografias impressas por correio para a sua morada. Tem de indicar a morada e o email.':
      [
    'Nous envoyons les photos imprimées par la poste à votre adresse. L\'adresse et l\'e-mail sont obligatoires.',
    'We post the printed photos to your address. You must give your address and email.'
  ],
  'Percebi': ['Compris', 'Got it'],
  'Extras': ['Options', 'Extras'],
  'Filme do evento': ['Film de l\'événement', 'Event film'],
  'Adicionado · {m}': ['Ajouté · {m}', 'Added · {m}'],
  'Toque para adicionar ou remover.': [
    'Touchez pour ajouter ou retirer.',
    'Tap to add or remove.'
  ],
  'Fotografias ({a} × {b})': ['Photos ({a} × {b})', 'Photos ({a} × {b})'],
  'Total': ['Total', 'Total'],
  'O resultado do pedido é incerto. Contacte a equipa antes de tentar novamente.':
      [
    'Le résultat de la commande est incertain. Contactez l\'équipe avant de réessayer.',
    'The result of the order is uncertain. Contact the team before trying again.'
  ],
  'Registar pedido · {m}': [
    'Enregistrer la commande · {m}',
    'Place order · {m}'
  ],
  'Voltar ao carrinho': ['Retour au panier', 'Back to cart'],
  'Indique qual é a sua mesa.': [
    'Indiquez votre table.',
    'Please enter your table.'
  ],
  'Na mesa use só letras (ex.: Noivos) ou só números (ex.: 12).': [
    'Pour la table, utilisez seulement des lettres (ex. : Mariés) ou des chiffres (ex. : 12).',
    'For the table, use only letters (e.g. Newlyweds) or only numbers (e.g. 12).'
  ],
  'Introduza o nome.': ['Saisissez le nom.', 'Please enter the name.'],
  'Para o envio por correio indique o email.': [
    'Pour l\'envoi par la poste, indiquez l\'e-mail.',
    'For postal delivery, please enter your email.'
  ],
  'Introduza um email válido.': [
    'Saisissez un e-mail valide.',
    'Please enter a valid email.'
  ],
  'Indique a morada de envio.': [
    'Indiquez l\'adresse de livraison.',
    'Please enter the delivery address.'
  ],
  'E agora?': ['Et maintenant ?', 'What now?'],
  'Dirija-se ao fotógrafo': [
    'Adressez-vous au photographe',
    'Go to the photographer'
  ],
  'Passe o iPad à próxima pessoa': [
    'Passez l\'iPad à la personne suivante',
    'Pass the iPad to the next person'
  ],
  'Voltar ao catálogo': ['Retour au catalogue', 'Back to the catalogue'],
};
