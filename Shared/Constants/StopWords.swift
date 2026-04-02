import Foundation

struct StopWords {
    static let list: Set<String> = [
        // Articles
        "a", "an", "the",
        // Pronouns
        "i", "me", "my", "myself", "we", "our", "ours", "ourselves",
        "you", "your", "yours", "yourself", "yourselves",
        "he", "him", "his", "himself", "she", "her", "hers", "herself",
        "it", "its", "itself", "they", "them", "their", "theirs", "themselves",
        "what", "which", "who", "whom", "this", "that", "these", "those",
        // Verbs (common)
        "am", "is", "are", "was", "were", "be", "been", "being",
        "have", "has", "had", "having", "do", "does", "did", "doing",
        "will", "would", "could", "should", "may", "might", "must",
        "shall", "can", "need", "dare", "ought", "used",
        // Prepositions
        "to", "of", "in", "for", "on", "with", "at", "by", "from",
        "up", "about", "into", "over", "after", "beneath", "under",
        "above", "below", "between", "among", "through", "during",
        "before", "behind", "beside", "beyond", "without", "within",
        // Conjunctions
        "and", "but", "or", "nor", "so", "yet", "both", "either",
        "neither", "not", "only", "own", "same", "than", "too", "very",
        "because", "while", "although", "if", "unless", "until", "when",
        "where", "why", "how", "whether", "however", "therefore",
        // Adverbs
        "just", "still", "already", "also", "even", "always", "never",
        "sometimes", "often", "usually", "rarely", "seldom", "ever",
        "here", "there", "now", "then", "again", "well", "back",
        "much", "many", "such", "no", "any", "some", "all", "each",
        "every", "other", "another", "most", "more", "less", "least",
        // Other common words
        "him", "her", "them", "he", "she", "it", "as", "his", "her",
        "their", "say", "said", "get", "got", "make", "made",
        "go", "went", "gone", "come", "came", "take", "took", "taken",
        "see", "saw", "seen", "know", "knew", "known", "think", "thought",
        "tell", "told", "find", "found", "give", "gave", "given",
        "become", "became", "let", "feel", "felt", "keep", "kept",
        "leave", "left", "call", "called", "turn", "turned",
        "show", "showed", "shown", "hear", "heard", "play", "played",
        "run", "ran", "move", "moved", "live", "lived", "believe", "believed",
        "hold", "held", "bring", "brought", "happen", "happened",
        "write", "wrote", "written", "provide", "provided", "sit", "sat",
        "stand", "stood", "lose", "lost", "pay", "paid", "meet", "met",
        "include", "included", "continue", "continued", "set", "learn",
        "learned", "change", "changed", "lead", "led", "understand",
        "understood", "watch", "watched", "follow", "followed", "stop",
        "stopped", "create", "created", "speak", "spoke", "spoken",
        "read", "allow", "allowed", "add", "added", "spend", "spent",
        "grow", "grew", "grown", "open", "opened", "walk", "walked",
        "win", "won", "offer", "offered", "remember", "remembered",
        "love", "loved", "consider", "considered", "appear", "appeared",
        "buy", "bought", "wait", "waited", "serve", "served", "die", "died",
        "send", "sent", "expect", "expected", "build", "built", "stay",
        "stayed", "fall", "fell", "fallen", "cut", "reach", "reached",
        "kill", "killed", "remain", "remained", "suggest", "suggested",
        "raise", "raised", "pass", "passed", "sell", "sold", "require",
        "required", "report", "reported", "decide", "decided", "pull",
        "pulled"
    ]
}
