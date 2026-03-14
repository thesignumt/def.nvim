local M = {}
local Job = require("plenary.job")

---Fetch word definition
---@param word string
---@param callback fun(result: table|nil)
function M.get_winfo(word, callback)
  if not word or word == "" then
    callback(nil)
    return
  end

  vim.system(
    { "curl", "-s", "https://api.dictionaryapi.dev/api/v2/entries/en/" .. word },
    { text = true },
    function(obj)
      vim.schedule(function()
        if obj.code ~= 0 then
          vim.notify(
            "Failed to fetch definition for: " .. word,
            vim.log.levels.WARN
          )
          callback(nil)
          return
        end

        local ok, data = pcall(vim.json.decode, obj.stdout)
        if not ok or type(data) ~= "table" or #data == 0 then
          vim.notify("No definition found for: " .. word, vim.log.levels.WARN)
          callback(nil)
          return
        end

        local ipa = data[1].phonetic
          or require("def.f").first_nonempty(data[1].phonetics, "text")
        local result = {}

        for _, meaning in ipairs(data[1].meanings or {}) do
          local defs = {}
          for _, d in ipairs(meaning.definitions or {}) do
            table.insert(defs, {
              definition = d.definition,
              example = d.example,
              synonyms = d.synonyms or {},
              antonyms = d.antonyms or {},
            })
          end

          table.insert(result, {
            partOfSpeech = meaning.partOfSpeech,
            ipa = ipa,
            definitions = defs,
            synonyms = meaning.synonyms or {},
            antonyms = meaning.antonyms or {},
          })
        end

        callback(#result > 0 and result or nil)
      end)
    end
  )
end

-- Word of the Day fetcher
function M.wotd(cb)
  Job
    :new({
      command = "curl",
      args = { "-s", "https://random-word-api.herokuapp.com/word" },
      on_exit = function(j, return_val)
        vim.schedule(function()
          if return_val == 0 then
            local ok, words =
              pcall(vim.fn.json_decode, table.concat(j:result(), ""))
            if ok and type(words) == "table" and words[1] then
              cb(words[1])
            else
              vim.notify("Failed to parse random word", vim.log.levels.WARN)
              cb(nil)
            end
          else
            vim.notify("Failed to fetch random word", vim.log.levels.WARN)
            cb(nil)
          end
        end)
      end,
    })
    :start()
end

return M
