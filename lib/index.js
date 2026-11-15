

import express from 'express';
import cors from 'cors';

const app = express();
app.use(cors());
app.use(express.json({ limit: '1mb' }));

app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} ${req.method} ${req.path}`);
  next();
});

function analyzeText(text) {
  const t = (text || '').toLowerCase().trim();
  const result = {
    intent: 'other',
    confidence: 0.5,
    summary: null,
    reply: null,
    suggestedActions: {},
  };

  if (!t) {
    result.reply = 'Please tell me what happened or ask a question.';
    return result;
  }

  if (t.includes('fire') || t.includes('smoke') || t.includes('burn')) {
    result.intent = 'fire';
    result.confidence = 0.95;
    result.summary = 'Possible fire reported';
    result.reply = 'It sounds like there may be a fire. Are people in immediate danger?';
    result.suggestedActions = {
      call_police: true,
      call_ambulance: true,
      police_number: '100',
      ambulance_number: '102',
      safetyTips: [
        'Move to a safe distance upwind',
        'Call emergency services immediately',
        'Do not attempt to fight large fires yourself',
      ],
    };
    return result;
  }

  if (t.includes('injury') || t.includes('bleeding') || t.includes('hurt')) {
    result.intent = 'medical';
    result.confidence = 0.92;
    result.summary = 'Possible medical emergency';
    result.reply = 'This sounds like a medical emergency. Is the person conscious and breathing?';
    result.suggestedActions = {
      call_ambulance: true,
      ambulance_number: '102',
      safetyTips: [
        'Check responsiveness and breathing',
        'Apply pressure to severe bleeding',
        'If trained, begin CPR if not breathing',
      ],
    };
    return result;
  }

  if (t.includes('robbery') || t.includes('theft') || t.includes('attack') || t.includes('assault')) {
    result.intent = 'crime';
    result.confidence = 0.9;
    result.summary = 'Possible crime in progress';
    result.reply = 'If you are in danger, find a safe place and call the police. Do you want me to call the police for you?';
    result.suggestedActions = {
      call_police: true,
      police_number: '100',
      safetyTips: [
        'Move to a safe location if possible',
        'Avoid confrontation',
        'Provide a description to police when safe',
      ],
    };
    return result;
  }

  if (t.includes('how') && t.includes('use')) {
    result.intent = 'faq';
    result.confidence = 0.8;
    result.reply = 'To report an emergency, tap EMERGENCY, confirm location, add a description, and optionally attach photo/video.';
    return result;
  }

  if (t.includes('hi') || t.includes('hello') || t.includes('hey')) {
    result.intent = 'greeting';
    result.confidence = 0.7;
    result.reply = 'Hello — how can I help you today?';
    return result;
  }

  if (t.includes('thank')) {
    result.intent = 'gratitude';
    result.confidence = 0.7;
    result.reply = 'You’re welcome. Stay safe.';
    return result;
  }

  if (t.includes('how are you')) {
    result.intent = 'smalltalk';
    result.confidence = 0.6;
    result.reply = 'I’m here to help. Tell me what happened or ask a question.';
    return result;
  }

 
  result.reply = `I hear you: "${text}". Tell me more or ask a question and I’ll help.`;
  return result;
}


app.get('/health', (req, res) => {
  res.json({ status: 'ok', time: new Date().toISOString() });
});

app.post('/api/chat', (req, res) => {
  try {
    const text = (req.body?.text || '').toString();
    if (!text || text.trim().length < 1) {
      return res.status(400).json({ error: 'text is required' });
    }

    const analysis = analyzeText(text);

    return res.json({
      reply: analysis.reply,
      intent: analysis.intent,
      confidence: analysis.confidence,
      summary: analysis.summary,
      suggestedActions: analysis.suggestedActions || {},
    });
  } catch (err) {
    console.error('chat error', err);
    return res.status(500).json({ error: 'internal error' });
  }
});


app.use((req, res) => {
  res.status(404).json({ error: 'not found' });
});


const port = process.env.PORT || 8080;
app.listen(port, '0.0.0.0', () => {
  console.log(`Chat NLU server listening on ${port}`);
});

export default app;