require "ffi"

module Duel
  # Ligação direta com a biblioteca da engine (ygopro-core) via FFI.
  # Nomes e tipos seguem o ocgapi.h e o ocgapi_types.h da versão fixada no submódulo.
  # A biblioteca é compilada por bin/build-engine.
  module Native
    extend FFI::Library
    ffi_lib ENV.fetch("OCGCORE_PATH") { Rails.root.join("vendor/engine/build/libocgcore.so").to_s }

    # Dados de uma carta que a engine pede pelo callback de leitura.
    class CardData < FFI::Struct
      layout :code, :uint32,
             :alias, :uint32,
             :setcodes, :pointer,
             :type, :uint32,
             :level, :uint32,
             :attribute, :uint32,
             :race, :uint64,
             :attack, :int32,
             :defense, :int32,
             :lscale, :uint32,
             :rscale, :uint32,
             :link_marker, :uint32
    end

    # PV iniciais e compras de cada time.
    class Player < FFI::Struct
      layout :starting_lp, :uint32,
             :starting_draw_count, :uint32,
             :draw_count_per_turn, :uint32
    end

    # Os callbacks ficam como ponteiros: recebem FFI::Function criadas uma vez só.
    class DuelOptions < FFI::Struct
      layout :seed, [ :uint64, 4 ],
             :flags, :uint64,
             :team1, Player,
             :team2, Player,
             :card_reader, :pointer,
             :payload1, :pointer,
             :script_reader, :pointer,
             :payload2, :pointer,
             :log_handler, :pointer,
             :payload3, :pointer,
             :card_reader_done, :pointer,
             :payload4, :pointer,
             :enable_unsafe_libraries, :uint8
    end

    class NewCardInfo < FFI::Struct
      layout :team, :uint8,
             :duelist, :uint8,
             :code, :uint32,
             :con, :uint8,
             :loc, :uint32,
             :seq, :uint32,
             :pos, :uint32
    end

    attach_function :create_duel, :OCG_CreateDuel, [ :pointer, DuelOptions.by_ref ], :int
    attach_function :destroy_duel, :OCG_DestroyDuel, [ :pointer ], :void
    attach_function :new_card, :OCG_DuelNewCard, [ :pointer, NewCardInfo.by_ref ], :void
    attach_function :start_duel, :OCG_StartDuel, [ :pointer ], :void
    attach_function :process, :OCG_DuelProcess, [ :pointer ], :int
    attach_function :get_message, :OCG_DuelGetMessage, [ :pointer, :pointer ], :pointer
    attach_function :set_response, :OCG_DuelSetResponse, [ :pointer, :buffer_in, :uint32 ], :void
    attach_function :load_script, :OCG_LoadScript, [ :pointer, :buffer_in, :uint32, :string ], :int
  end
end
