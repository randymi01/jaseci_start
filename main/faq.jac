node cai_state {
    has name;
    can init_wlk_ctx {
        new_wlk_ctx = {
            "intent": null,
            "entities": {},
            "prev_state": null,
            "next_state": null,
            "respond": false
        };
        if ("entities" in visitor.wlk_ctx) {
            // Carry over extracted entities from previous interaction
            new_wlk_ctx["entities"] = visitor.wlk_ctx["entities"];
        }
        visitor.wlk_ctx = new_wlk_ctx;
    }
    can nlu {}
    can process {
        if (visitor.wlk_ctx["prev_state"]): visitor.wlk_ctx["respond"] = true;
        else {
            visitor.wlk_ctx["next_state"] = net.root();
            visitor.wlk_ctx["prev_state"] = here;
        }
    }
    can nlg {}
}

node faq_root:cai_state {
    can use.qa_classify;
    can nlu {
        if (!visitor.wlk_ctx["prev_state"]) {
            answers = -->.answer;
            best_answer = use.qa_classify(
                text = visitor.question,
                classes = answers
            );
            visitor.wlk_ctx["intent"] = best_answer["match"];
        }
    }
    can process {
        if (visitor.wlk_ctx["prev_state"]): visitor.wlk_ctx["respond"] = true;
        else {
            for n in --> {
                if (n.context["answer"] == visitor.wlk_ctx["intent"]){
                    visitor.wlk_ctx["next_state"] = n;
                    break;
                }
            }
            visitor.wlk_ctx["prev_state"] = here;
        }
    }
    can nlg {
        visitor.response = "I can answer a variety of FAQs related to Tesla. What can I help you with?";
    }
}
node faq_state:cai_state {
    has question;
    has answer;
    can nlg {
        visitor.response = here.answer;
    }
}

# root node is automatically defined
graph faq {
    has anchor faq_root;
    spawn {
        // Spawning the nodes
        faq_root = spawn node::faq_root;
        faq_answer_1 = spawn node::faq_state(
            question="How do I configure my order?",
            answer="To configure your order, log into your Tesla account."
        );
        faq_answer_2 = spawn node::faq_state(
            question="How do I order a tesla",
            answer="Visit our design studio to place your order."
        );
        faq_answer_3 = spawn node::faq_state(
            question="Can I request a test drive",
            answer="Yes. You must be a minimum of 25 years of age."
        );

        // Connecting the nodes together
        faq_root ++> faq_answer_1;
        faq_root ++> faq_answer_2;
        faq_root ++> faq_answer_3;
    }
}

# specifies walker for graph. init always runs first
walker init {
    # walker runs this command only for root node which connects root to graph::faq defined above
    root {
        std.out("Walker Init has run on Root");
        # here is self referential pointer to walker

        # spawns an edge from root to faq graph at faq graph anchor
        # spawn here ++> graph::faq;

        # creates connection to newly initialized faq_root (doesn't connect to graph above)
        spawn here ++> node::faq_root;

        # Ingest Faq walker builds nodes from json
        spawn here walker::ingest_faq(kb_file = "tesla_faq.json");

        # Ask walker goes through the newly built graph
        spawn here walker::ask;
    }
}

walker ask {
    can use.qa_classify;
    has question;
    root {
        std.out("Walker Ask has run on Root");
        question = std.input("AMA > ");

        # take is where the walker traverses to
        take --> node::faq_root;
    }
    faq_root {
        # answers takes a list of answer attributes from any node that has faq_root as a parent
        answers = -->.answer;
        best_answer = use.qa_classify(
            text = question,
            classes = answers
        );
        std.out("Walker Ask has run on faq_root");
        take --> node::faq_state(answer==best_answer["match"]);
    }
    faq_state {
        std.out(here.answer);
    }
}
# Create dot graph from main.jac
# jac dot main.jac -o main.dot

# Output to pdf
# exit()
# dot -Tpdf main.dot -o main.pdf

walker ingest_faq {
    has kb_file;
    root: take --> node::faq_root;
    # if at faq_root node, load the qa file then create faq_state nodes for each entry in the json
    faq_root {
        kb = file.load_json(kb_file);
        for faq in kb {
            answer = faq["answer"];
            spawn here ++> node::faq_state(answer=answer);
        }
    }
}