import 'dart:math';

enum Suit {hearts, diamonds, clubs, spades}
enum Rank {ace, two, three, four, five, six, seven, eight, nine, ten, jack, queen, king}

class PlayingCard{
  final Suit suit;
  final Rank rank;
  bool faceUp;

  PlayingCard({required this.suit, required this.rank, this.faceUp = true});

  int get value{
    switch(rank){
      case Rank.ace:
        return 1; // 1 or 11 handled in logic
      case Rank.two:
        return 2;
      case Rank.three:
        return 3;
      case Rank.four:
        return 4;
      case Rank.five:
        return 5;
      case Rank.six:
        return 6;
      case Rank.seven:
        return 7;
      case Rank.eight:
        return 8;
      case Rank.nine:
        return 9;
      case Rank.ten:
      case Rank.jack:
      case Rank.queen:
      case Rank.king:
        return 10;
    }
  }
  String get imagePath{
    if(!faceUp) return "assets/images/card_back.png";

    String suitName = suit.toString().split(".").last;
    String rankName = rank.toString().split(".").last;
    String rankNameForString="";

    //overkill solution for bad formatting
    switch(rankName){
      case "two":
        rankNameForString="02";
      case "three":
        rankNameForString="03";
      case "four":
        rankNameForString="04";
      case "five":
        rankNameForString="05";
      case "six":
        rankNameForString="06";
      case "seven":
        rankNameForString="07";
      case "eight":
        rankNameForString="08";
      case "nine":
        rankNameForString="09";
      case "ten":
        rankNameForString="10";
      case "jack":
        rankNameForString="J";
      case "queen":
        rankNameForString="Q";
      case "king":
        rankNameForString="K";
      case "ace":
        rankNameForString="A";

    }

    return "assets/images/card_${suitName}_${rankNameForString}.png";
  }
}

class Deck{
  final List<PlayingCard> cards = [];
  final random = Random();

  Deck(){
    reset();
  }

  void reset(){
    cards.clear();
    for(var suit in Suit.values){
      for(var rank in Rank.values){
        cards.add(PlayingCard(suit: suit, rank: rank));
      }
    }
    cards.shuffle(random);
  }

  PlayingCard? drawCard(){
    if(cards.isEmpty) return null;
    return cards.removeLast();
  }

}

class Hand{
  final List<PlayingCard> cards = [];

  void addCard(PlayingCard card){
    cards.add(card);
  }

  void clear(){
    cards.clear();
  }

  int get value{
    int sum=0;
    int aces=0;

    for(var card in cards){
      if(card.rank==Rank.ace){
        aces++;
      }
      sum = sum+card.value;
    }

    while(sum > 21 && aces > 0){
      sum=sum-10;
      aces--;
    }

    return sum;
  }

  bool get isBust => value > 21;
  bool get isBlackjack => cards.length==2 && value==21;

}