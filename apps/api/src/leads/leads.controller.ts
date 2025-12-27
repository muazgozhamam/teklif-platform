import { BadRequestException, Body, Controller, Get, Param, Post, Put } from '@nestjs/common';
import { LeadAnswerDto, WizardAnswerDto } from './dto/lead-answer.dto';
import { LeadsService } from './leads.service';

@Controller('leads')
export class LeadsController {
  constructor(private leads: LeadsService) {}

  @Post()
  create(@Body() body: { initialText: string }) {
    const initialText = (body?.initialText ?? '').trim();
    if (!initialText) throw new BadRequestException('initialText is required');
    return this.leads.create(initialText);
  }

  @Get(':id/next')
  next(@Param('id') id: string) {
    return this.leads.nextQuestion(id);
  }

  // create OR update (upsert) answer
  @Put(':id/answer')
  upsertAnswer(
    @Param('id') id: string,
    @Body() body: LeadAnswerDto,
  ) {
    const key = (body?.key ?? '').trim();
    const answer = (body?.answer ?? '').trim();
    if (!key) throw new BadRequestException('key is required');
    if (!answer) throw new BadRequestException('answer is required');
    return this.leads.upsertAnswer(id, key, answer);
  }

  // keep POST for backward compatibility, but enforce validation and call upsert
  @Post(':id/answer')
  answer(
    @Param('id') id: string,
    @Body() body: LeadAnswerDto,
  ) {
    const key = (body?.key ?? '').trim();
    const answer = (body?.answer ?? '').trim();
    if (!key) throw new BadRequestException('key is required');
    if (!answer) throw new BadRequestException('answer is required');
    return this.leads.upsertAnswer(id, key, answer);
  }

  @Get(':id')
  get(@Param('id') id: string) {
    return this.leads.getLead(id);
  }


  /**
   * Sprint-1: Lead Wizard (tek tek soru)
   * Statelesstir: Deal alanlarına bakıp sıradaki soruyu üretir.
   */
  @Post(':id/wizard/next-question')
  async wizardNextQuestion(@Param('id') id: string) {
    return this.leads.wizardNextQuestion(id);
  }

  @Post(':id/wizard/answer')
  async wizardAnswer(@Param('id') id: string, @Body() body: WizardAnswerDto) {
    return this.leads.wizardAnswer(id, body?.key, body?.answer);
  }

}
