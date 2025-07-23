//
//  SentencePieceBridge.h
//  Bridge header for SentencePiece C++ integration
//

#ifndef SentencePieceWrapper_h
#define SentencePieceWrapper_h

#ifdef __cplusplus
extern "C" {
#endif

// Opaque pointer to SentencePiece processor
typedef void* SentencePieceProcessor;

// Create and load a SentencePiece model
SentencePieceProcessor sentencepiece_create(const char* model_path);

// Encode text to pieces (tokens)
// Returns number of pieces, fills pieces array with token strings
int sentencepiece_encode_as_pieces(SentencePieceProcessor processor, 
                                  const char* text,
                                  char*** pieces);

// Encode text to IDs
// Returns number of IDs, fills ids array
int sentencepiece_encode_as_ids(SentencePieceProcessor processor,
                               const char* text,
                               int** ids);

// Get vocabulary size
int sentencepiece_get_piece_size(SentencePieceProcessor processor);

// Convert piece to ID
int sentencepiece_piece_to_id(SentencePieceProcessor processor, const char* piece);

// Convert ID to piece
const char* sentencepiece_id_to_piece(SentencePieceProcessor processor, int id);

// Get score for a piece
float sentencepiece_get_score(SentencePieceProcessor processor, int id);

// Clean up
void sentencepiece_free_processor(SentencePieceProcessor processor);
void sentencepiece_free_pieces(char** pieces, int count);
void sentencepiece_free_ids(int* ids);

#ifdef __cplusplus
}
#endif

#endif /* SentencePieceWrapper_h */