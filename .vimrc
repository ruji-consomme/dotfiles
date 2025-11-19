" 行番号を表示する
set number
" 検索結果をハイライトする
set hlsearch
" vimで開いているファイル名を表示する
set laststatus=2
" タブを表示するときの幅
set tabstop=4
" タブを挿入するときの幅
set shiftwidth=4 

" インサートモードのESCをjjにバインド
inoremap <silent> jj <ESC>


sealed class Animal {
    abstract val type: String
}

data class Dog(
    override val type: String = "dog",
    val name: String
) : Animal()

data class Cat(
    override val type: String = "cat",
    val name: String
) : Animal()

class AnimalDeserializer : JsonDeserializer<Animal> {
    override fun deserialize(
        json: JsonElement,
        typeOfT: Type,
        context: JsonDeserializationContext
    ): Animal {
        val obj = json.asJsonObject
        val type = obj["type"].asString

        return when (type) {
            "dog" -> context.deserialize(obj, Dog::class.java)
            "cat" -> context.deserialize(obj, Cat::class.java)
            else -> throw JsonParseException("Unknown type: $type")
        }
    }
}


